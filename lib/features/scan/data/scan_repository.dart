import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository class that handles the entire scan submission process.
/// Uses EXISTING 'scans' table and 'eye-images' bucket.
class ScanRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Submits a complete scan record to the EXISTING database table.
  Future<void> submitScan({
    required String imagePath,
    required Map<String, dynamic> formData,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      // 1. Upload Image to EXISTING 'eye-images' bucket
      final file = File(imagePath);
      final fileExt = imagePath.split('.').last;
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      debugPrint('Uploading image to eye-images bucket: $fileName');

      await _supabase.storage.from('eye-images').upload(
        fileName,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = _supabase.storage.from('eye-images').getPublicUrl(fileName);
      debugPrint('Image URL: $imageUrl');

      // 2. Insert Data into EXISTING 'scans' table
      await _supabase.from('scans').insert({
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
        'image_url': imageUrl,

        // -- EXISTING COLUMNS --
        'prediction': 'Pending', // Placeholder until AI runs
        'confidence': 0.0,
        'symptoms': formData['suspected_disease'], // Save category as "symptoms" text (Backup)

        // -- NEW RESEARCH COLUMNS (Added via ALTER TABLE) --
        'patient_age': formData['patient_age'],
        'patient_gender': formData['patient_gender'],
        'suspected_disease': formData['suspected_disease'],
        'clinical_data': formData['clinical_data'], // The JSON data
      });

      debugPrint('Scan record saved successfully!');
    } catch (e) {
      debugPrint('Error submitting scan: $e');
      rethrow;
    }
  }

  /// Fetches all scan records for the current user
  Future<List<Map<String, dynamic>>> getUserScans() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('scans')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Gets a single scan by ID
  Future<Map<String, dynamic>?> getScanById(String scanId) async {
    final response = await _supabase
        .from('scans')
        .select()
        .eq('id', scanId)
        .maybeSingle();

    return response;
  }

  /// Deletes a scan record and its associated image
  Future<void> deleteScan(String scanId, String imageUrl) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // Extract file path from URL
    final uri = Uri.parse(imageUrl);
    final pathSegments = uri.pathSegments;
    final storagePath = pathSegments.sublist(pathSegments.indexOf('eye-images') + 1).join('/');

    // Delete from storage
    await _supabase.storage.from('eye-images').remove([storagePath]);

    // Delete from database
    await _supabase.from('scans').delete().eq('id', scanId);
  }
}
