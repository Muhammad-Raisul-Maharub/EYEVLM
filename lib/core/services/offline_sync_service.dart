import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

/// Offline-First Service for background sync of scans
/// 
/// Features:
/// - Copies images to persistent storage before queuing
/// - Saves scans locally when offline
/// - Automatically syncs when connectivity returns
/// - Maintains a queue of pending uploads
class OfflineSyncService {
  static OfflineSyncService? _instance;
  Database? _database;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  
  // Notifier for pending count changes
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
  
  // Notifier for sync status
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);
  
  OfflineSyncService._();
  
  static OfflineSyncService get instance {
    _instance ??= OfflineSyncService._();
    return _instance!;
  }

  /// Get the persistent directory for offline images
  Future<Directory> get _offlineImagesDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${appDir.path}/offline_queue_images');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  /// Initialize the offline database and start listening for connectivity
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint("⚠️ OfflineSyncService: Web platform not supported");
      return;
    }
    
    await _initDatabase();
    _startConnectivityListener();
    await _updatePendingCount();
    
    // Attempt sync on startup
    await syncPendingScans();
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'eyevlm_offline_queue.db');
    
    _database = await openDatabase(
      path,
      version: 2, // Bumped version for migration
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            image_paths TEXT NOT NULL,
            form_data TEXT NOT NULL,
            attachment_paths TEXT,
            retry_count INTEGER DEFAULT 0,
            last_error TEXT,
            status TEXT DEFAULT 'pending'
          )
        ''');
        debugPrint("✅ Offline queue database created");
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add status column if upgrading from v1
          try {
            await db.execute('ALTER TABLE pending_scans ADD COLUMN status TEXT DEFAULT "pending"');
          } catch (e) {
            debugPrint("⚠️ Migration error (may already exist): $e");
          }
        }
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

  /// Copy image to persistent storage and return new path
  Future<String> _copyImageToPersistentStorage(String originalPath, String queueId) async {
    try {
      final file = File(originalPath);
      if (!await file.exists()) {
        throw Exception('Source file does not exist: $originalPath');
      }
      
      final offlineDir = await _offlineImagesDir;
      final fileName = '${queueId}_${basename(originalPath)}';
      final newPath = '${offlineDir.path}/$fileName';
      
      await file.copy(newPath);
      debugPrint("📁 Copied image to persistent storage: $newPath");
      
      return newPath;
    } catch (e) {
      debugPrint("❌ Failed to copy image: $e");
      rethrow;
    }
  }

  /// Save a scan locally for later upload
  /// Copies images to persistent storage to avoid PathNotFoundException
  Future<int> queueScan({
    required List<String> imagePaths,
    required Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
  }) async {
    if (_database == null) await _initDatabase();
    
    final queueId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Copy images to persistent storage
    List<String> persistentImagePaths = [];
    for (int i = 0; i < imagePaths.length; i++) {
      try {
        final originalPath = imagePaths[i];
        final persistentPath = await _copyImageToPersistentStorage(originalPath, '${queueId}_img$i');
        persistentImagePaths.add(persistentPath);
      } catch (e) {
        debugPrint("⚠️ Failed to copy image $i: $e");
        // Still try to use original path as fallback
        persistentImagePaths.add(imagePaths[i]);
      }
    }
    
    // Copy attachments to persistent storage
    List<String> persistentAttachmentPaths = [];
    if (attachments != null) {
      for (int i = 0; i < attachments.length; i++) {
        final file = attachments[i];
        if (file.path != null) {
          try {
            final persistentPath = await _copyImageToPersistentStorage(file.path!, '${queueId}_attach$i');
            persistentAttachmentPaths.add(persistentPath);
          } catch (e) {
            debugPrint("⚠️ Failed to copy attachment $i: $e");
            persistentAttachmentPaths.add(file.path!);
          }
        }
      }
    }
    
    final id = await _database!.insert('pending_scans', {
      'created_at': DateTime.now().toIso8601String(),
      'image_paths': jsonEncode(persistentImagePaths),
      'form_data': jsonEncode(formData),
      'attachment_paths': jsonEncode(persistentAttachmentPaths),
      'retry_count': 0,
      'status': 'pending',
    });
    
    debugPrint("📦 Scan queued offline (ID: $id) with ${persistentImagePaths.length} images");
    await _updatePendingCount();
    
    return id;
  }

  /// Update the pending count notifier
  Future<void> _updatePendingCount() async {
    final count = await getPendingCount();
    pendingCountNotifier.value = count;
  }

  /// Get count of pending scans
  Future<int> getPendingCount() async {
    if (_database == null) return 0;
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM pending_scans WHERE status = "pending"'
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get all pending scans
  Future<List<Map<String, dynamic>>> getPendingScans() async {
    if (_database == null) return [];
    return await _database!.query(
      'pending_scans',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
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
    isSyncingNotifier.value = true; // Update notifier
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
          
          // Verify all image files exist before uploading
          List<String> validImagePaths = [];
          for (final path in imagePaths) {
            final file = File(path);
            if (await file.exists()) {
              validImagePaths.add(path);
            } else {
              debugPrint("⚠️ Image file not found: $path");
            }
          }
          
          if (validImagePaths.isEmpty) {
            throw Exception('No valid image files found for this scan');
          }
          
          // Convert paths back to PlatformFile objects
          List<PlatformFile>? attachments;
          if (attachmentPaths.isNotEmpty) {
            attachments = [];
            for (final path in attachmentPaths) {
              final file = File(path);
              if (await file.exists()) {
                attachments.add(PlatformFile(
                  path: path,
                  name: basename(path),
                  size: await file.length(),
                ));
              }
            }
          }
          
          // Upload to Supabase
          await _uploadScan(validImagePaths, formData, attachments);
          
          // Mark as synced
          await _database!.update(
            'pending_scans',
            {'status': 'synced'},
            where: 'id = ?',
            whereArgs: [scan['id']],
          );
          
          // Clean up local files
          await _cleanupSyncedFiles(imagePaths, attachmentPaths);
          
          successCount++;
          debugPrint("✅ Synced scan ID: ${scan['id']}");
          
        } catch (e) {
          // Update retry count and error
          final retryCount = (scan['retry_count'] ?? 0) + 1;
          
          // Mark as failed if too many retries
          final status = retryCount >= 5 ? 'failed' : 'pending';
          
          await _database!.update(
            'pending_scans',
            {
              'retry_count': retryCount,
              'last_error': e.toString(),
              'status': status,
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
      isSyncingNotifier.value = false; // Reset notifier
      await _updatePendingCount();
    }
    
    return SyncResult(
      success: successCount,
      failed: failCount,
      message: "Synced $successCount, failed $failCount",
    );
  }

  /// Clean up local files after successful sync
  Future<void> _cleanupSyncedFiles(List<String> imagePaths, List<String> attachmentPaths) async {
    for (final path in [...imagePaths, ...attachmentPaths]) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint("🗑️ Cleaned up: $path");
        }
      } catch (e) {
        debugPrint("⚠️ Failed to cleanup file: $e");
      }
    }
  }

  /// Upload a scan to Supabase
  Future<void> _uploadScan(
    List<String> imagePaths,
    Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
  ) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    final String scanSessionId = '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    List<String> uploadedImageUrls = [];
    
    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final file = File(imagePath);
      
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }
      
      final fileExt = extension(imagePath).replaceFirst('.', '');
      final fileName = 'scans/$scanSessionId/eye_image_$i.$fileExt';
      
      await supabase.storage.from('eye-images').upload(
        fileName,
        file,
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
        final file = File(doc.path!);
        if (!await file.exists()) continue;
        
        final docName = 'scans/$scanSessionId/attachments/${doc.name}';
        await supabase.storage.from('eye-images').upload(
          docName,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        final docUrl = supabase.storage.from('eye-images').getPublicUrl(docName);
        attachmentLinks.add({'name': doc.name, 'url': docUrl});
      }
    }
    
    // ========== RUN AI INFERENCE ==========
    String prediction = 'Pending';
    double confidence = 0.0;
    Map<String, dynamic>? confidenceMap;
    String? explanation;

    try {
      // Primary image URL (first image)
      final String primaryImageUrl = uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : '';
      
      // Production Backend URL (Render)
      const String backendUrl = 'https://eyevlm-backend.onrender.com/infer'; 
      
      // Use first image for inference
      final inferencePayload = jsonEncode({
        "image_url": primaryImageUrl,
        "symptoms": formData['suspected_disease'],
        "language": "en" 
      });

      // Get current session token for Auth
      final session = supabase.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint("⚠️ No Auth Token found. Skipping AI Analysis during sync.");
      } else {
        // Retry mechanism with exponential backoff for Render cold starts
        const int maxRetries = 2; // Fewer retries for background sync
        const Duration baseTimeout = Duration(seconds: 90); 
        
        http.Response? response;
        
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
          try {
            debugPrint("🔄 Sync AI Inference attempt $attempt/$maxRetries...");
            
            response = await http.post(
              Uri.parse(backendUrl),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
              },
              body: inferencePayload,
            ).timeout(baseTimeout);
            
            if (response.statusCode == 200) {
              break; // Success
            } 
            if (attempt < maxRetries) await Future.delayed(Duration(seconds: 5));
          } catch (e) {
            debugPrint("⚠️ Sync AI attempt $attempt failed: $e");
            if (attempt < maxRetries) await Future.delayed(Duration(seconds: 5));
          }
        }

        if (response != null && response.statusCode == 200) {
          final result = jsonDecode(response.body);
          prediction = result['predicted_class'] ?? 'Pending';
          confidenceMap = result['confidence'];
          explanation = result['explanation_text'];
          
          if (confidenceMap != null && confidenceMap.containsKey(prediction)) {
            confidence = (confidenceMap[prediction] as num).toDouble();
          }
          
          debugPrint("✅ AI Analysis Complete during Sync: $prediction ($confidence)");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Failed to connect to AI Backend during sync: $e");
    }

    // Insert record with AI results
    final clinicalData = Map<String, dynamic>.from(formData['clinical_data'] ?? {});
    clinicalData['attachments'] = attachmentLinks;
    clinicalData['synced_from_offline'] = true;
    clinicalData['ai_explanation'] = explanation;
    clinicalData['ai_confidence_map'] = confidenceMap;
    
    // Use original creation time if available, otherwise now
    String createdAt = DateTime.now().toUtc().toIso8601String();
    if (formData['created_at'] != null) {
      try {
         // parsed as local, converted to utc for storage
         createdAt = DateTime.parse(formData['created_at']).toUtc().toIso8601String(); 
      } catch (e) {
         debugPrint("⚠️ Could not parse original created_at: $e");
      }
    }

    await supabase.from('scans').insert({
      'user_id': user.id,
      'created_at': createdAt,
      'image_url': uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : '',
      'image_urls': uploadedImageUrls,
      'prediction': prediction,
      'confidence': confidence,
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
    
    // Clean up all files first
    final pending = await _database!.query('pending_scans');
    for (final scan in pending) {
      final imagePaths = List<String>.from(jsonDecode(scan['image_paths'].toString()));
      final attachmentPaths = List<String>.from(jsonDecode(scan['attachment_paths'].toString()));
      await _cleanupSyncedFiles(imagePaths, attachmentPaths);
    }
    
    await _database!.delete('pending_scans');
    await _updatePendingCount();
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
