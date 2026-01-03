import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

import 'package:eyevlm_app/core/constants/app_constants.dart';

final submissionServiceProvider = Provider((ref) => SubmissionService());

class SubmissionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String get _backendUrl => AppConstants.baseUrl;

  Future<String> uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      // Sanitize filename: Replace colons with dashes to avoid URL/Storage issues
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileExt = p.extension(imageFile.path).isEmpty ? '.jpg' : p.extension(imageFile.path);
      final fileName = '$timestamp$fileExt';
      final userId = _supabase.auth.currentUser!.id;
      final path = '$userId/$fileName';
      
      // Default to image/jpeg if lookup fails, NOT octet-stream, so browser can view it
      final mimeType = imageFile.mimeType ?? lookupMimeType(imageFile.path) ?? 'image/jpeg';

      await _supabase.storage.from('eye-images').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600', 
          upsert: false,
          contentType: mimeType,
        ),
      );

      final imageUrl = _supabase.storage.from('eye-images').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  Future<Map<String, dynamic>> submitInference({
    required String imageUrl,
    required String symptoms,
    String language = 'en',
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception("Not authenticated");

      final response = await http.post(
        Uri.parse('$_backendUrl/infer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'image_url': imageUrl,
          'symptoms': symptoms,
          'language': language,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Save to Database
        final user = _supabase.auth.currentUser;
        if (user != null) {
          // Extract the scalar confidence value for the predicted class
          // to match the 'confidence FLOAT' column in the database.
          final pClass = result['predicted_class'];
          final confMap = result['confidence'] as Map<String, dynamic>;
          final confValue = confMap[pClass] ?? 0.0;

          await _supabase.from('scans').insert({
            'user_id': user.id,
            'image_url': imageUrl,
            'symptoms': symptoms,
            'prediction': pClass,
            'confidence': confValue, // Now sending a double/float, not a Map
          });
          debugPrint("✅ Data saved to history!");
        }

        return result;
      } else {
        throw Exception('Inference failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Backend error: $e');
    }
  }
}
