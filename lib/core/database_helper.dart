import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite database helper for offline-first architecture.
/// This is the single source of truth for user scan data.
/// 
/// Features:
/// - Stores scans locally for offline access
/// - Tracks sync status for background upload
/// - JSON encoding/decoding for complex fields
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('eyevlm_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create scans table with JSON fields for complex data
    await db.execute('''
      CREATE TABLE scans (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        image_paths TEXT NOT NULL,
        symptoms TEXT NOT NULL,
        ai_prediction TEXT,
        doctor_notes TEXT,
        confidence REAL DEFAULT 0,
        patient_age TEXT,
        patient_gender TEXT,
        suspected_disease TEXT,
        clinical_data TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    debugPrint("✅ DatabaseHelper: Local scans table created");
  }

  // ---------------------------------------------------------------------------
  // CRUD OPERATIONS
  // ---------------------------------------------------------------------------

  /// Saves a scan locally. Returns the inserted row count.
  Future<int> createScan(Map<String, dynamic> scanData) async {
    final db = await instance.database;
    
    // Ensure complex lists are encoded to strings before saving
    final Map<String, dynamic> row = {
      'id': scanData['id'],
      'user_id': scanData['user_id'],
      'image_paths': scanData['image_paths'] is String 
          ? scanData['image_paths'] 
          : jsonEncode(scanData['image_paths']),
      'symptoms': scanData['symptoms'] is String 
          ? scanData['symptoms'] 
          : jsonEncode(scanData['symptoms']),
      'ai_prediction': scanData['ai_prediction'] ?? 'Pending',
      'doctor_notes': scanData['doctor_notes'] ?? '',
      'confidence': scanData['confidence'] ?? 0.0,
      'patient_age': scanData['patient_age']?.toString() ?? '',
      'patient_gender': scanData['patient_gender'] ?? '',
      'suspected_disease': scanData['suspected_disease'] ?? '',
      'clinical_data': scanData['clinical_data'] is String 
          ? scanData['clinical_data'] 
          : jsonEncode(scanData['clinical_data'] ?? {}),
      'is_synced': 0, // Always starts as unsynced
      'created_at': scanData['created_at'] ?? DateTime.now().toIso8601String(),
    };

    return await db.insert('scans', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Fetches ALL scans (For History Tab).
  /// Automatically decodes the JSON strings back into Lists/Maps.
  Future<List<Map<String, dynamic>>> getAllScans({String? userId}) async {
    final db = await instance.database;
    
    List<Map<String, dynamic>> result;
    if (userId != null) {
      result = await db.query(
        'scans',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    } else {
      result = await db.query('scans', orderBy: 'created_at DESC');
    }

    return result.map((json) {
      final map = Map<String, dynamic>.from(json);
      // Decode JSON strings back to usable Dart objects
      try {
        map['image_paths'] = jsonDecode(json['image_paths'] as String);
      } catch (e) {
        map['image_paths'] = [json['image_paths']];
      }
      try {
        map['symptoms'] = jsonDecode(json['symptoms'] as String);
      } catch (e) {
        map['symptoms'] = json['symptoms'];
      }
      try {
        map['clinical_data'] = jsonDecode(json['clinical_data'] as String? ?? '{}');
      } catch (e) {
        map['clinical_data'] = {};
      }
      // Convert to match Supabase format for compatibility
      map['prediction'] = map['ai_prediction'];
      map['image_url'] = (map['image_paths'] is List && (map['image_paths'] as List).isNotEmpty)
          ? map['image_paths'][0]
          : '';
      map['image_urls'] = map['image_paths'];
      return map;
    }).toList();
  }

  /// Fetches only scans waiting for upload (For Background Sync).
  Future<List<Map<String, dynamic>>> getUnsyncedScans() async {
    final db = await instance.database;
    final result = await db.query('scans', where: 'is_synced = ?', whereArgs: [0]);
    
    return result.map((json) {
      final map = Map<String, dynamic>.from(json);
      try {
        map['image_paths'] = jsonDecode(json['image_paths'] as String);
      } catch (e) {
        map['image_paths'] = [json['image_paths']];
      }
      try {
        map['symptoms'] = jsonDecode(json['symptoms'] as String);
      } catch (e) {
        map['symptoms'] = json['symptoms'];
      }
      try {
        map['clinical_data'] = jsonDecode(json['clinical_data'] as String? ?? '{}');
      } catch (e) {
        map['clinical_data'] = {};
      }
      return map;
    }).toList();
  }

  /// Marks a scan as "Uploaded" after Supabase accepts it.
  Future<int> markAsSynced(String id) async {
    final db = await instance.database;
    return await db.update(
      'scans',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get count of unsynced scans
  Future<int> getUnsyncedCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scans WHERE is_synced = 0'
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Delete a scan by ID
  Future<int> deleteScan(String id) async {
    final db = await instance.database;
    return await db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  /// Debug Utility: Clears everything
  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('scans');
    debugPrint("🗑️ DatabaseHelper: All scans cleared");
  }
}
