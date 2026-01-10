import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/offline_sync_service.dart'; // Ensure connectivity check availability
import 'package:connectivity_plus/connectivity_plus.dart';

/// Admin service for managing all user scans
/// Only accessible by admin users
class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all scans from all users (admin only)
  Future<List<Map<String, dynamic>>> getAllScans({
    int limit = 100,
    int offset = 0,
    String? searchQuery,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);

      if (isOnline) {
        // Online: Fetch from Supabase
        var query = _supabase
            .from('scans')
            .select('*')
            .limit(limit)
            .range(offset, offset + limit - 1);
        
        // Apply sorting
        if (sortBy != null) {
          query = query.order(sortBy, ascending: ascending);
        } else {
          query = query.order('created_at', ascending: false);
        }
        
        final response = await query;
        List<Map<String, dynamic>> results;
        
        // Filter by search query if provided (filtering locally after fetch for simplicity with text search)
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final searchLower = searchQuery.toLowerCase();
          results = (response as List<dynamic>).where((scan) {
            final prediction = (scan['prediction'] ?? '').toString().toLowerCase();
            final symptoms = (scan['symptoms'] ?? '').toString().toLowerCase();
            final notes = (scan['notes'] ?? '').toString().toLowerCase();
            return prediction.contains(searchLower) ||
                   symptoms.contains(searchLower) ||
                   notes.contains(searchLower);
          }).map((e) => e as Map<String, dynamic>).toList();
        } else {
          results = (response as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        }

        // Cache results if it's the default view (no search/sort or just basic sort)
        if (offset == 0 && (searchQuery == null || searchQuery.isEmpty)) {
           await _cacheScans(results);
        }

        return results;
      } else {
        // Offline: Fetch from Cache
        debugPrint("📴 AdminService: Fetching from cache");
        final cached = await _getCachedScans();
        
        if (searchQuery != null && searchQuery.isNotEmpty) {
           final searchLower = searchQuery.toLowerCase();
           return cached.where((scan) {
            final prediction = (scan['prediction'] ?? '').toString().toLowerCase();
            final symptoms = (scan['symptoms'] ?? '').toString().toLowerCase();
            final notes = (scan['notes'] ?? '').toString().toLowerCase();
            return prediction.contains(searchLower) ||
                   symptoms.contains(searchLower) ||
                   notes.contains(searchLower);
          }).toList();
        }
        return cached;
      }
    } catch (e) {
      debugPrint('❌ AdminService.getAllScans error: $e');
      // On error (e.g. timeout), try cache
      return await _getCachedScans();
    }
  }

  // --- Caching Helpers ---
  static const String _adminCacheKey = 'admin_scans_cache';

  Future<void> _cacheScans(List<Map<String, dynamic>> scans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure complex objects are safe for JSON (they should be coming from Supabase)
      await prefs.setString(_adminCacheKey, jsonEncode(scans));
    } catch (e) {
      debugPrint("⚠️ Failed to cache admin scans: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _getCachedScans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_adminCacheKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        return jsonList.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Failed to load cached admin scans: $e");
    }
    return [];
  }

  /// Get total scan count
  Future<int> getTotalScanCount() async {
    try {
      final response = await _supabase
          .from('scans')
          .select('id')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('❌ AdminService.getTotalScanCount error: $e');
      return 0;
    }
  }

  /// Get a single scan by ID
  Future<Map<String, dynamic>?> getScanById(int scanId) async {
    try {
      final response = await _supabase
          .from('scans')
          .select('*')
          .eq('id', scanId)
          .single();
      return response;
    } catch (e) {
      debugPrint('❌ AdminService.getScanById error: $e');
      return null;
    }
  }

  /// Update a scan record
  Future<bool> updateScan(int scanId, Map<String, dynamic> updates) async {
    try {
      // Add updated timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      await _supabase
          .from('scans')
          .update(updates)
          .eq('id', scanId);
      
      debugPrint('✅ Scan $scanId updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ AdminService.updateScan error: $e');
      return false;
    }
  }

  /// Delete a scan and all associated files
  Future<bool> deleteScan(int scanId, String? imageUrl) async {
    try {
      // First, delete associated images from storage
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _deleteStorageFiles(imageUrl);
      }
      
      // Delete the scan record
      await _supabase
          .from('scans')
          .delete()
          .eq('id', scanId);
      
      debugPrint('✅ Scan $scanId deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ AdminService.deleteScan error: $e');
      return false;
    }
  }

  /// Delete multiple scans
  Future<int> deleteMultipleScans(List<int> scanIds) async {
    int deletedCount = 0;
    
    for (final scanId in scanIds) {
      try {
        final scan = await getScanById(scanId);
        if (scan != null) {
          final success = await deleteScan(scanId, scan['image_url']);
          if (success) deletedCount++;
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete scan $scanId: $e');
      }
    }
    
    return deletedCount;
  }

  /// Download scan data as JSON
  Future<String> exportScansToJson(List<Map<String, dynamic>> scans) async {
    try {
      final exportData = {
        'exported_at': DateTime.now().toIso8601String(),
        'total_count': scans.length,
        'scans': scans,
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      debugPrint('❌ AdminService.exportScansToJson error: $e');
      rethrow;
    }
  }

  /// Download image from URL
  Future<Uint8List?> downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('❌ AdminService.downloadImage error: $e');
      return null;
    }
  }

  /// Save image to device
  Future<String?> saveImageToDevice(Uint8List imageBytes, String filename) async {
    try {
      if (kIsWeb) {
        // Web download handled differently
        return null;
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/EyeVLM_Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final filePath = '${downloadsDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      return filePath;
    } catch (e) {
      debugPrint('❌ AdminService.saveImageToDevice error: $e');
      return null;
    }
  }

  /// Delete storage files associated with a scan
  Future<void> _deleteStorageFiles(String imageUrl) async {
    try {
      // Extract file path from URL
      // URL format: https://xxx.supabase.co/storage/v1/object/public/eye-images/user_id/filename.jpg
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name and file path
      final bucketIndex = pathSegments.indexOf('eye-images');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        
        await _supabase.storage
            .from('eye-images')
            .remove([filePath]);
        
        debugPrint('✅ Deleted storage file: $filePath');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete storage file: $e');
    }
  }

  /// Get scan statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allScans = await getAllScans(limit: 10000);
      
      // Calculate statistics
      final totalScans = allScans.length;
      final predictions = <String, int>{};
      
      for (final scan in allScans) {
        final prediction = scan['prediction']?.toString() ?? 'Unknown';
        predictions[prediction] = (predictions[prediction] ?? 0) + 1;
      }
      
      // Get unique users
      final uniqueUsers = allScans.map((s) => s['user_id']).toSet().length;
      
      // Scans in last 7 days
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final recentScans = allScans.where((s) {
        final createdAt = DateTime.tryParse(s['created_at'] ?? '');
        return createdAt != null && createdAt.isAfter(weekAgo);
      }).length;
      
      return {
        'total_scans': totalScans,
        'unique_users': uniqueUsers,
        'recent_scans': recentScans,
        'predictions': predictions,
      };
    } catch (e) {
      debugPrint('❌ AdminService.getStatistics error: $e');
      return {};
    }
  }
}

/// Provider for admin service
final adminServiceProvider = Provider((ref) => AdminService());
