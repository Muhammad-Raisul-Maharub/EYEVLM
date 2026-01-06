import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

/// Offline-First Service for background sync of scans
/// 
/// Features:
/// - Saves scans locally when offline
/// - Automatically syncs when connectivity returns
/// - Maintains a queue of pending uploads
class OfflineSyncService {
  static OfflineSyncService? _instance;
  Database? _database;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  
  OfflineSyncService._();
  
  static OfflineSyncService get instance {
    _instance ??= OfflineSyncService._();
    return _instance!;
  }

  /// Initialize the offline database and start listening for connectivity
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint("⚠️ OfflineSyncService: Web platform not supported");
      return;
    }
    
    await _initDatabase();
    _startConnectivityListener();
    
    // Attempt sync on startup
    await syncPendingScans();
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'eyevlm_offline_queue.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            image_paths TEXT NOT NULL,
            form_data TEXT NOT NULL,
            attachment_paths TEXT,
            retry_count INTEGER DEFAULT 0,
            last_error TEXT
          )
        ''');
        debugPrint("✅ Offline queue database created");
      },
    );
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && !_isSyncing) {
        debugPrint("🌐 Connectivity restored - starting sync");
        syncPendingScans();
      }
    });
  }

  /// Check if we're online
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Save a scan locally for later upload
  Future<int> queueScan({
    required List<String> imagePaths,
    required Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
  }) async {
    if (_database == null) await _initDatabase();
    
    // Convert attachment files to paths
    List<String> attachmentPaths = [];
    if (attachments != null) {
      for (final file in attachments) {
        if (file.path != null) {
          attachmentPaths.add(file.path!);
        }
      }
    }
    
    final id = await _database!.insert('pending_scans', {
      'created_at': DateTime.now().toIso8601String(),
      'image_paths': jsonEncode(imagePaths),
      'form_data': jsonEncode(formData),
      'attachment_paths': jsonEncode(attachmentPaths),
      'retry_count': 0,
    });
    
    debugPrint("📦 Scan queued offline (ID: $id)");
    return id;
  }

  /// Get count of pending scans
  Future<int> getPendingCount() async {
    if (_database == null) return 0;
    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM pending_scans');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get all pending scans
  Future<List<Map<String, dynamic>>> getPendingScans() async {
    if (_database == null) return [];
    return await _database!.query('pending_scans', orderBy: 'created_at ASC');
  }

  /// Sync all pending scans when online
  Future<SyncResult> syncPendingScans() async {
    if (_isSyncing) {
      return SyncResult(success: 0, failed: 0, message: "Sync already in progress");
    }
    
    if (!(await isOnline)) {
      return SyncResult(success: 0, failed: 0, message: "No internet connection");
    }
    
    _isSyncing = true;
    int successCount = 0;
    int failCount = 0;
    
    try {
      final pendingScans = await getPendingScans();
      debugPrint("🔄 Syncing ${pendingScans.length} pending scans...");
      
      for (final scan in pendingScans) {
        try {
          final imagePaths = List<String>.from(jsonDecode(scan['image_paths']));
          final formData = Map<String, dynamic>.from(jsonDecode(scan['form_data']));
          final attachmentPaths = List<String>.from(jsonDecode(scan['attachment_paths'] ?? '[]'));
          
          // Convert paths back to PlatformFile objects
          List<PlatformFile>? attachments;
          if (attachmentPaths.isNotEmpty) {
            attachments = attachmentPaths.map((path) {
              final file = File(path);
              return PlatformFile(
                path: path,
                name: path.split('/').last,
                size: file.existsSync() ? file.lengthSync() : 0,
              );
            }).toList();
          }
          
          // Upload to Supabase
          await _uploadScan(imagePaths, formData, attachments);
          
          // Remove from queue on success
          await _database!.delete('pending_scans', where: 'id = ?', whereArgs: [scan['id']]);
          successCount++;
          debugPrint("✅ Synced scan ID: ${scan['id']}");
          
        } catch (e) {
          // Update retry count and error
          await _database!.update(
            'pending_scans',
            {
              'retry_count': (scan['retry_count'] ?? 0) + 1,
              'last_error': e.toString(),
            },
            where: 'id = ?',
            whereArgs: [scan['id']],
          );
          failCount++;
          debugPrint("❌ Failed to sync scan ${scan['id']}: $e");
        }
      }
    } finally {
      _isSyncing = false;
    }
    
    return SyncResult(
      success: successCount,
      failed: failCount,
      message: "Synced $successCount, failed $failCount",
    );
  }

  /// Upload a scan to Supabase
  Future<void> _uploadScan(
    List<String> imagePaths,
    Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
  ) async {
    // This mirrors the ScanRepository logic but for queued scans
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    final String scanSessionId = '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    List<String> uploadedImageUrls = [];
    
    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final fileExt = imagePath.split('.').last;
      final fileName = 'scans/$scanSessionId/eye_image_$i.$fileExt';
      
      await supabase.storage.from('eye-images').upload(
        fileName,
        File(imagePath),
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      final imageUrl = supabase.storage.from('eye-images').getPublicUrl(fileName);
      uploadedImageUrls.add(imageUrl);
    }
    
    // Upload attachments if any
    List<Map<String, String>> attachmentLinks = [];
    if (attachments != null) {
      for (final doc in attachments) {
        if (doc.path == null) continue;
        final docName = 'scans/$scanSessionId/attachments/${doc.name}';
        await supabase.storage.from('eye-images').upload(
          docName,
          File(doc.path!),
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        final docUrl = supabase.storage.from('eye-images').getPublicUrl(docName);
        attachmentLinks.add({'name': doc.name, 'url': docUrl});
      }
    }
    
    // Insert record
    final clinicalData = Map<String, dynamic>.from(formData['clinical_data'] ?? {});
    clinicalData['attachments'] = attachmentLinks;
    clinicalData['synced_from_offline'] = true;
    
    await supabase.from('scans').insert({
      'user_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
      'image_url': uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : '',
      'image_urls': uploadedImageUrls,
      'prediction': 'Pending', // Will need AI inference later
      'confidence': 0.0,
      'symptoms': formData['suspected_disease'],
      'clinical_data': clinicalData,
      'patient_age': formData['patient_age'],
      'patient_gender': formData['patient_gender'],
      'suspected_disease': formData['suspected_disease'],
    });
  }

  /// Clear all pending scans (use with caution)
  Future<void> clearQueue() async {
    if (_database == null) return;
    await _database!.delete('pending_scans');
    debugPrint("🗑️ Offline queue cleared");
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _database?.close();
  }
}

/// Result of a sync operation
class SyncResult {
  final int success;
  final int failed;
  final String message;
  
  SyncResult({required this.success, required this.failed, required this.message});
  
  bool get hasFailures => failed > 0;
  int get total => success + failed;
}
