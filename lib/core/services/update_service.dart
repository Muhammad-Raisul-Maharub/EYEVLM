import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

/// GitHub-based Auto-Update Engine for Android
/// 
/// Uses url_launcher to open APK download in browser.
/// Note: In-app installer packages have compatibility issues with
/// modern Android Gradle Plugin, so browser download is the reliable approach.
class UpdateService {
  static const String owner = "Muhammad-Raisul-Maharub";
  static const String repo = "EYEVLM";
  
  /// Checks GitHub Releases for available updates
  Future<Map<String, String>?> checkForUpdate() async {
    if (!Platform.isAndroid) {
      debugPrint("📱 UpdateService: Skipping on non-Android");
      return null;
    }
    
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      Version currentVersion = Version.parse(packageInfo.version);
      debugPrint("📱 Current version: $currentVersion");

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name'] ?? '';
        if (tagName.startsWith('v')) tagName = tagName.substring(1);
        if (tagName.isEmpty) return null;
        
        Version latestVersion = Version.parse(tagName);
        debugPrint("🌐 Latest: $latestVersion");

        if (latestVersion > currentVersion) {
          debugPrint("🆕 Update available!");
          List assets = data['assets'] ?? [];
          for (var asset in assets) {
            if (asset['name']?.toString().endsWith('.apk') ?? false) {
              return {
                'version': tagName,
                'url': asset['browser_download_url'] ?? '',
                'release_notes': data['body'] ?? 'New version available',
              };
            }
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Update check failed: $e");
    }
    return null;
  }

  /// Shows forced update dialog
  void showForcedUpdateDialog(BuildContext context, String url, String version, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text("Update to v$version", style: const TextStyle(fontSize: 18))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "A new version of EyeVLM is required.\n\n"
                "1. Tap 'Download' below\n"
                "2. Browser will open & download starts\n"
                "3. Tap the download notification to install",
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text(
                  notes.length > 100 ? '${notes.substring(0, 100)}...' : notes,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.download),
                label: const Text("Download Update"),
                onPressed: () async {
                  final uri = Uri.parse(url);
                  try {
                    // Directly launch without canLaunchUrl check - it can incorrectly
                    // return false on Android 11+ due to package visibility restrictions
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (context.mounted) {
                      if (launched) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Download started. Open the APK to install when complete."),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Could not open browser. Please visit: $url"),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint("❌ Failed to launch URL: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error opening browser: $e"),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Call on app start to check for updates
  Future<void> checkAndForceUpdate(BuildContext context) async {
    final info = await checkForUpdate();
    if (info != null && context.mounted) {
      showForcedUpdateDialog(context, info['url']!, info['version']!, info['release_notes']!);
    }
  }
}
