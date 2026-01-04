import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Repository class that handles the entire scan submission process.
/// Uses EXISTING 'scans' table and 'eye-images' bucket.
class ScanRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Submits a complete scan record to the EXISTING database table.
  Future<void> submitScan({
    required String imagePath,
    required Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
    Uint8List? imageBytes, // Added for Web
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      // Generate a Scan Session ID (Timestamp based for now, but acts as a unique folder)
      final String scanSessionId = '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
      
      // 1. Upload Image to EXISTING 'eye-images' bucket
      // Structure: scans/{scanSessionId}/eye_image.{ext}
      final fileExt = imagePath.split('.').last;
      final fileName = 'scans/$scanSessionId/eye_image.$fileExt';

      debugPrint('Uploading image to eye-images bucket: $fileName');

      if (kIsWeb) {
           if (imageBytes == null) throw Exception("Web upload requires imageBytes to be passed");
           await _supabase.storage.from('eye-images').uploadBinary(
             fileName,
             imageBytes,
             fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
           );
      } else {
           await _supabase.storage.from('eye-images').upload(
             fileName,
             File(imagePath),
             fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
           );
      }

      final imageUrl = _supabase.storage.from('eye-images').getPublicUrl(fileName);
      debugPrint('Image URL: $imageUrl');

      // 1.5 Upload Attachments (if any)
      // Structure: scans/{scanSessionId}/attachments/{filename}
      List<Map<String, String>> attachmentLinks = [];
      if (attachments != null) {
        for (final doc in attachments) {
          try {
            final docName = 'scans/$scanSessionId/attachments/${doc.name}';
            // Handle Web vs Native
            if (kIsWeb) {
               await _supabase.storage.from('eye-images').uploadBinary(
                 docName,
                 doc.bytes!,
                 fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
               );
            } else {
               await _supabase.storage.from('eye-images').upload(
                 docName,
                 File(doc.path!),
                 fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
               );
            }
            final docUrl = _supabase.storage.from('eye-images').getPublicUrl(docName);
            attachmentLinks.add({'name': doc.name, 'url': docUrl});
          } catch (e) {
            debugPrint("Failed to upload attachment ${doc.name}: $e");
          }
        }
      }
      
      // Add attachments to clinical data
      final clinicalData = Map<String, dynamic>.from(formData['clinical_data']);
      clinicalData['attachments'] = attachmentLinks;

      // 2. Run Inference (Call Python Backend)
      String prediction = 'Pending';
      double confidence = 0.0;
      Map<String, dynamic>? confidenceMap;
      String? explanation;

      try {
        // Production Backend URL (Render)
        const String backendUrl = 'https://eyevlm-backend.onrender.com/infer'; 
        
        // Prepare payload
        final inferencePayload = jsonEncode({
          "image_url": imageUrl,
          "symptoms": formData['suspected_disease'], // Use disease category as context
          "language": "en" 
        });

        // Get current session token for Auth
        final session = _supabase.auth.currentSession;
        final token = session?.accessToken;

        if (token == null) {
          debugPrint("⚠️ No Auth Token found. Skipping AI Analysis.");
          throw Exception("No Auth Token");
        }

        final response = await http.post(
          Uri.parse(backendUrl),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: inferencePayload,
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          prediction = result['predicted_class'];
          confidenceMap = result['confidence'];
          explanation = result['explanation_text'];
          
          // Get confidence for the predicted class
          if (confidenceMap != null && confidenceMap.containsKey(prediction)) {
             confidence = (confidenceMap[prediction] as num).toDouble();
          }
          
          debugPrint("✅ AI Analysis Complete: $prediction");
        } else {
          debugPrint("⚠️ Backend Error: ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        debugPrint("⚠️ Failed to connect to AI Backend: $e");
        // Fallback to 'Pending' so data is still saved
      }

      // 3. Insert Data into EXISTING 'scans' table
      await _supabase.from('scans').insert({
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
        'image_url': imageUrl,

        // -- EXISTING COLUMNS --
        'prediction': prediction, 
        'confidence': confidence,
        'symptoms': formData['suspected_disease'], 
        
        // Save the full analysis details in clinical_data
        // We merge the AI results into the existing clinical data
        'clinical_data': {
           ...clinicalData,
           'ai_explanation': explanation,
           'ai_confidence_map': confidenceMap,
        },

        // -- NEW RESEARCH COLUMNS --
        'patient_age': formData['patient_age'],
        'patient_gender': formData['patient_gender'],
        'suspected_disease': formData['suspected_disease'],
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
