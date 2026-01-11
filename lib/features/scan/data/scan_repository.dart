import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/database_helper.dart';
import '../../../core/services/offline_auth_service.dart';

/// Repository class that handles the entire scan submission process.
/// Uses EXISTING 'scans' table and 'eye-images' bucket.
/// 
/// CHANGES v1.1:
/// - Supports multiple images (max 5) via `imagePaths` list
/// - No automatic cropping (only manual crops by user are used)
/// - Stores images in `image_urls` JSONB array (backward compatible with `image_url`)
class ScanRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Submits a complete scan record to the EXISTING database table.
  /// Supports multiple images (max 5) - no automatic cropping.
  /// Falls back to offline queue if no internet connection.
  Future<void> submitScan({
    required List<String> imagePaths, // List of image paths (max 5)
    required Map<String, dynamic> formData,
    List<PlatformFile>? attachments,
    List<Uint8List>? imageBytesList, // For Web multi-image
  }) async {
    var user = _supabase.auth.currentUser;
    String? userId = user?.id;
    
    // Fallback to cached userId if offline/session expired
    if (userId == null) {
      userId = await OfflineAuthService().getCachedUserId();
    }

    if (userId == null) throw Exception("User not logged in");

    // Validate max 5 images
    if (imagePaths.length > 5) {
      throw Exception("Maximum 5 images allowed per scan");
    }

    // ========== STEP 1: ALWAYS SAVE LOCALLY FIRST ==========
    // This ensures data is immediately available in History, even offline
    final String localScanId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
    
    if (!kIsWeb) {
      try {
        await DatabaseHelper.instance.createScan({
          'id': localScanId,
          'user_id': userId,
          'image_paths': imagePaths,
          'symptoms': formData['suspected_disease'],
          'ai_prediction': 'Pending',
          'confidence': 0.0,
          'patient_age': formData['patient_age'],
          'patient_gender': formData['patient_gender'],
          'suspected_disease': formData['suspected_disease'],
          'clinical_data': formData['clinical_data'] ?? {},
          'is_synced': 0, // Will be updated after successful upload
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint("✅ Scan saved locally first (ID: $localScanId)");
      } catch (e) {
        debugPrint("⚠️ Failed to save locally: $e");
        // Continue anyway - try online upload
      }
    }

    // ========== STEP 2: CHECK CONNECTIVITY ==========
    if (!kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);
      
      if (!isOnline) {
        debugPrint("📴 Offline - scan saved locally, will sync later");
        // Queue for background sync
        await OfflineSyncService.instance.queueScan(
          imagePaths: imagePaths,
          formData: formData,
          attachments: attachments,
        );
        return; // Exit early - data is saved locally, will sync when online
      }
    }

    try {
      // Generate a Scan Session ID (Timestamp based, acts as unique folder)
      final String scanSessionId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // ========== UPLOAD ALL IMAGES (No automatic cropping) ==========
      // Images are already processed (manually cropped by user if desired)
      List<String> uploadedImageUrls = [];
      
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final imageBytes = imageBytesList != null && i < imageBytesList.length 
            ? imageBytesList[i] 
            : null;
        
        // Upload Image to 'eye-images' bucket
        // Structure: scans/{scanSessionId}/eye_image_{i}.{ext}
        final fileExt = imagePath.split('.').last;
        final fileName = 'scans/$scanSessionId/eye_image_$i.$fileExt';

        debugPrint('📤 Uploading image $i to: $fileName');

        // Determine MIME type from extension
        String contentType = 'image/jpeg'; // Default
        if (fileExt.toLowerCase() == 'png') {
          contentType = 'image/png';
        } else if (fileExt.toLowerCase() == 'gif') {
          contentType = 'image/gif';
        } else if (fileExt.toLowerCase() == 'webp') {
          contentType = 'image/webp';
        }

        if (kIsWeb) {
          if (imageBytes == null) {
            throw Exception("Web upload requires imageBytes for image $i");
          }
          await _supabase.storage.from('eye-images').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: FileOptions(cacheControl: '3600', upsert: false, contentType: contentType),
          );
        } else {
          await _supabase.storage.from('eye-images').upload(
            fileName,
            File(imagePath),
            fileOptions: FileOptions(cacheControl: '3600', upsert: false, contentType: contentType),
          );
        }

        final imageUrl = _supabase.storage.from('eye-images').getPublicUrl(fileName);
        uploadedImageUrls.add(imageUrl);
        debugPrint('✅ Image $i uploaded: $imageUrl');
      }
      
      // Primary image URL (first image for backward compatibility)
      final String primaryImageUrl = uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : '';

      // ========== UPLOAD ATTACHMENTS (if any) ==========
      // Structure: scans/{scanSessionId}/attachments/{filename}
      List<Map<String, String>> attachmentLinks = [];
      if (attachments != null) {
        for (final doc in attachments) {
          try {
            final docName = 'scans/$scanSessionId/attachments/${doc.name}';
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
            debugPrint('📎 Attachment uploaded: ${doc.name}');
          } catch (e) {
            debugPrint("⚠️ Failed to upload attachment ${doc.name}: $e");
          }
        }
      }
      
      // Add attachments to clinical data
      final clinicalData = Map<String, dynamic>.from(formData['clinical_data'] ?? {});
      clinicalData['attachments'] = attachmentLinks;

      // ========== RUN AI INFERENCE ==========
      String prediction = 'Pending';
      double confidence = 0.0;
      Map<String, dynamic>? confidenceMap;
      String? explanation;

      try {
        // Production Backend URL (Render)
        const String backendUrl = 'https://eyevlm-backend.onrender.com/infer'; 
        
        // Use first image for inference
        final inferencePayload = jsonEncode({
          "image_url": primaryImageUrl,
          "symptoms": formData['suspected_disease'],
          "language": "en" 
        });

        // Get current session token for Auth
        final session = _supabase.auth.currentSession;
        final token = session?.accessToken;

        if (token == null) {
          debugPrint("⚠️ No Auth Token found. Skipping AI Analysis.");
        } else {
          // Retry mechanism with exponential backoff for Render cold starts
          const int maxRetries = 3;
          const Duration baseTimeout = Duration(seconds: 90); // Long timeout for Render cold start
          
          http.Response? response;
          Exception? lastError;
          
          for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try {
              debugPrint("🔄 AI Inference attempt $attempt/$maxRetries...");
              
              response = await http.post(
                Uri.parse(backendUrl),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $token",
                },
                body: inferencePayload,
              ).timeout(baseTimeout);
              
              if (response.statusCode == 200) {
                break; // Success - exit retry loop
              } else if (response.statusCode >= 500) {
                // Server error - retry
                debugPrint("⚠️ Backend Error ${response.statusCode}, retrying...");
                if (attempt < maxRetries) {
                  await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
                }
              } else {
                // Client error - don't retry
                debugPrint("❌ Client Error: ${response.statusCode} - ${response.body}");
                break;
              }
            } on TimeoutException {
              lastError = TimeoutException('Request timed out');
              debugPrint("⏱️ Timeout on attempt $attempt, retrying...");
              if (attempt < maxRetries) {
                await Future.delayed(Duration(seconds: attempt * 2));
              }
            } catch (e) {
              lastError = e as Exception;
              debugPrint("⚠️ Error on attempt $attempt: $e");
              if (attempt < maxRetries) {
                await Future.delayed(Duration(seconds: attempt * 2));
              }
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
            
            debugPrint("✅ AI Analysis Complete: $prediction ($confidence)");
          } else if (lastError != null) {
            debugPrint("❌ All retries failed: $lastError");
          } else if (response != null) {
            debugPrint("⚠️ Backend Error: ${response.statusCode} - ${response.body}");
          }
        }
      } catch (e) {
        debugPrint("⚠️ Failed to connect to AI Backend: $e");
        // Fallback to 'Pending' so data is still saved
      }

      // ========== INSERT INTO DATABASE ==========
      await _supabase.from('scans').insert({
        'user_id': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        
        // Backward compatible single image URL
        'image_url': primaryImageUrl,
        
        // New: Array of all image URLs
        'image_urls': uploadedImageUrls,
        
        // AI Results
        'prediction': prediction, 
        'confidence': confidence,
        'symptoms': formData['suspected_disease'], 
        
        // Clinical data with AI results merged
        'clinical_data': {
          ...clinicalData,
          'ai_explanation': explanation,
          'ai_confidence_map': confidenceMap,
        },

        // Research columns
        'patient_age': formData['patient_age'],
        'patient_gender': formData['patient_gender'],
        'suspected_disease': formData['suspected_disease'],
      });

      debugPrint('✅ Scan record saved successfully with ${uploadedImageUrls.length} images!');
      
      // ========== STEP 4: MARK LOCAL SCAN AS SYNCED ==========
      if (!kIsWeb) {
        try {
          await DatabaseHelper.instance.markAsSynced(localScanId);
          debugPrint("✅ Local scan marked as synced");
        } catch (e) {
          debugPrint("⚠️ Failed to mark local scan as synced: $e");
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting scan: $e');
      rethrow;
    }
  }

  /// Fetches all scan records for the current user
  Future<List<Map<String, dynamic>>> getUserScans() async {
    final userId = _supabase.auth.currentUser?.id ?? await OfflineAuthService().getCachedUserId();
    if (userId == null) return [];

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);

    final dbHelper = DatabaseHelper.instance;

    if (isOnline) {
      try {
        final response = await _supabase
            .from('scans')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final scans = List<Map<String, dynamic>>.from(response);

        // Cache scans locally
        for (var scan in scans) {
          await dbHelper.createScan(scan);
          await dbHelper.markAsSynced(scan['id'].toString());
        }

        // Sort just in case API didn't (ensure newest first)
        scans.sort((a, b) {
           final da = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(1970);
           final db = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(1970);
           return db.compareTo(da); // Newest first
        });

        return scans;
      } catch (e) {
        debugPrint("⚠️ Online fetch failed, falling back to local DB: $e");
        return await dbHelper.getAllScans(userId: userId);
      }
    } else {
      // Offline: Fetch from local DB
      debugPrint("📴 OFFLINE: Fetching scans from local DB");
      return await dbHelper.getAllScans(userId: userId);
    }
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

  /// Deletes a scan record and ALL associated files (images + attachments)
  Future<void> deleteScan(int scanId, String imageUrl) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      // Extract the session folder path from URL
      // URL format: .../eye-images/scans/{sessionId}/eye_image_0.ext
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final eyeImagesIndex = pathSegments.indexOf('eye-images');
      
      if (eyeImagesIndex == -1) {
        debugPrint("Could not parse image URL for deletion: $imageUrl");
        // Fallback: just delete the database record
        await _supabase.from('scans').delete().eq('id', scanId);
        return;
      }

      // Get the folder path (e.g., scans/{sessionId})
      final storagePath = pathSegments.sublist(eyeImagesIndex + 1).join('/');
      final folderPath = storagePath.substring(0, storagePath.lastIndexOf('/'));
      
      debugPrint("🗑️ Deleting all files in folder: $folderPath");

      // List all files in the session folder
      final List<FileObject> files = await _supabase.storage
          .from('eye-images')
          .list(path: folderPath);

      // Delete main folder files (all eye_images)
      if (files.isNotEmpty) {
        final filesToDelete = files.map((f) => '$folderPath/${f.name}').toList();
        await _supabase.storage.from('eye-images').remove(filesToDelete);
        debugPrint("Deleted ${filesToDelete.length} files from $folderPath");
      }

      // Also check for attachments subfolder
      try {
        final List<FileObject> attachments = await _supabase.storage
            .from('eye-images')
            .list(path: '$folderPath/attachments');
        
        if (attachments.isNotEmpty) {
          final attachmentsToDelete = attachments
              .map((f) => '$folderPath/attachments/${f.name}')
              .toList();
          await _supabase.storage.from('eye-images').remove(attachmentsToDelete);
          debugPrint("Deleted ${attachmentsToDelete.length} attachments");
        }
      } catch (e) {
        // Attachments folder may not exist, that's fine
        debugPrint("No attachments folder or error: $e");
      }

      // Delete from database
      await _supabase.from('scans').delete().eq('id', scanId);
      debugPrint("✅ Scan $scanId deleted successfully with all files");
    } catch (e) {
      debugPrint("❌ Error during scan deletion: $e");
      // Still try to delete the database record even if storage fails
      await _supabase.from('scans').delete().eq('id', scanId);
      rethrow;
    }
  }
}
