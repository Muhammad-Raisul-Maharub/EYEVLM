import 'dart:async';
import 'dart:io';
// Added: Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Added for animations
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/providers/refresh_provider.dart';
import '../../core/utils/app_notifications.dart'; // Import
import '../../core/services/pdf_service.dart';
import '../../core/database_helper.dart'; // Local database
import 'history_details_dialog.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Changed from Stream to List for local database support
  List<Map<String, dynamic>> _scans = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isExporting = false;
  bool _isDownloading = false; // For download overlay
  // Keep track of auth subscription to cancel it
  late final StreamSubscription<AuthState> _authSubscription;
  final Set<String> _deletedIds = {}; // Changed to String for local IDs
  
  // Selection mode state
  bool _isSelectionMode = false;
  final Set<int> _selectedScanIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize immediately
    _loadScans();

    // Listen for Auth Changes (in case session restores late or user switches)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
       final event = data.event;
       if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
         _loadScans();
       }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  /// Load scans from local database (offline-first) AND Supabase for complete data
  Future<void> _loadScans() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint("🔄 HistoryScreen: Loading scans for User ID: $userId");

    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        // Web: Always use Supabase (no local DB)
        final response = await Supabase.instance.client
            .from('scans')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        
        if (mounted) {
          setState(() {
            _scans = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      } else {
        // Mobile: Load from local DB first (instant), then sync from Supabase
        final localScans = await DatabaseHelper.instance.getAllScans(userId: userId);
        
        // Show local scans immediately for responsive UI
        if (mounted) {
          setState(() {
            _scans = localScans;
            _isLoading = false;
          });
        }
        debugPrint("✅ Loaded ${localScans.length} scans from local database");
        
        // Also fetch from Supabase and merge (remote data takes precedence)
        try {
          final remoteScans = await Supabase.instance.client
              .from('scans')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          
          final remoteList = List<Map<String, dynamic>>.from(remoteScans);
          debugPrint("📡 Fetched ${remoteList.length} scans from Supabase");
          
          // Merge: Use remote data if available (has actual predictions)
          // Keep local-only scans that haven't synced yet
          final merged = _mergeScans(localScans, remoteList);
          
          if (mounted) {
            setState(() => _scans = merged);
          }
          debugPrint("🔄 Merged to ${merged.length} total scans");
        } catch (e) {
          debugPrint("⚠️ Could not sync from Supabase: $e");
          // Keep showing local scans - that's fine for offline mode
        }
      }
    } catch (e) {
      debugPrint("❌ Error loading scans: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotifications.showError(context, 'Error loading history: $e');
      }
    }
  }
  
  /// Merge local and remote scans, preferring remote data with actual predictions
  List<Map<String, dynamic>> _mergeScans(
    List<Map<String, dynamic>> localScans,
    List<Map<String, dynamic>> remoteScans,
  ) {
    // Create a map of remote scans by image_url for quick lookup
    final Map<String, Map<String, dynamic>> remoteByUrl = {};
    for (final scan in remoteScans) {
      final url = scan['image_url']?.toString() ?? '';
      if (url.isNotEmpty) {
        remoteByUrl[url] = scan;
      }
    }
    
    // Build merged list
    final List<Map<String, dynamic>> merged = [];
    final Set<String> addedUrls = {};
    
    // Add all remote scans first (they have actual server data)
    for (final scan in remoteScans) {
      merged.add(scan);
      final url = scan['image_url']?.toString() ?? '';
      if (url.isNotEmpty) addedUrls.add(url);
    }
    
    // Add local-only scans (not yet synced to server)
    for (final scan in localScans) {
      final url = scan['image_url']?.toString() ?? '';
      // Check if this is a local file path (not synced yet)
      if (url.startsWith('/') && !addedUrls.contains(url)) {
        merged.add(scan);
      }
    }
    
    // Sort by created_at descending
    merged.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    
    return merged;
  }

  // Robust Delete Function - Deletes image, attachments, and database record
  Future<void> deleteScan(dynamic scanId, String imageUrl) async {
    // Optimistic Update: Remove from UI immediately
    setState(() {
      _deletedIds.add(scanId.toString()); 
      _isDeleting = true;
    }); 

    final supabase = Supabase.instance.client;

    try {
      // --- 1. Robust Path Extraction ---
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('eye-images');

      if (bucketIndex == -1) {
        throw Exception("Invalid URL: 'eye-images' bucket not found.");
      }

      // Get the full file path (e.g., scans/userId_timestamp/eye_image.jpg)
      final filePath = segments.sublist(bucketIndex + 1).join('/');
      // Get the folder path (e.g., scans/userId_timestamp)
      final folderPath = filePath.substring(0, filePath.lastIndexOf('/'));

      debugPrint("🗑️ Deleting scan folder: $folderPath");

      // --- 2. Delete main image file ---
      try {
        await supabase.storage.from('eye-images').remove([filePath]);
        debugPrint("✅ Main image deleted: $filePath");
      } catch (e) {
        debugPrint("⚠️ Could not delete main image: $e");
      }

      // --- 3. Delete attachments subfolder ---
      try {
        final attachmentsPath = '$folderPath/attachments';
        final List<FileObject> attachments = await supabase.storage
            .from('eye-images')
            .list(path: attachmentsPath);
        
        if (attachments.isNotEmpty) {
          final attachmentPaths = attachments
              .map((f) => '$attachmentsPath/${f.name}')
              .toList();
          await supabase.storage.from('eye-images').remove(attachmentPaths);
          debugPrint("✅ Deleted ${attachmentPaths.length} attachments");
        }
      } catch (e) {
        debugPrint("📎 No attachments folder or error: $e");
      }

      // --- 4. Delete from Database ---
      await supabase.from('scans').delete().eq('id', scanId).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException("Database deletion timed out"),
      );
      debugPrint("✅ Database record $scanId deleted");

      if (mounted) {
        AppNotifications.showSuccess(context, 'Scan and attachments deleted');
      }

    } catch (e) {
      debugPrint("❌ Error during deletion: $e");
      if (mounted) {
        setState(() {
          _deletedIds.remove(scanId.toString());
        });
        AppNotifications.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void showDeleteConfirmation(dynamic scanId, String imageUrl, String prediction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Scan?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This action cannot be undone."),
              const SizedBox(height: 15),
              
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 150,
                  width: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
              
              const SizedBox(height: 10),
              Text(
                "Result: $prediction",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); 
                deleteScan(scanId, imageUrl);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Exports all scans to a CSV file for thesis data analysis
  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Fetch all scans
      final response = await Supabase.instance.client
          .from('scans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final scans = List<Map<String, dynamic>>.from(response);

      if (scans.isEmpty) {
        if (mounted) {
          AppNotifications.showInfo(context, 'No data to export');
        }
        return;
      }

      // Build CSV content
      final StringBuffer csv = StringBuffer();
      
      // Header row
      csv.writeln('ID,Created At,Image URL,Prediction,Confidence,Patient Age,Patient Gender,Suspected Disease,Symptoms,Notes');

      // Data rows
      for (final scan in scans) {
        final id = scan['id'] ?? '';
        final createdAt = scan['created_at'] ?? '';
        final imageUrl = scan['image_url'] ?? '';
        final prediction = scan['prediction'] ?? '';
        final confidence = scan['confidence'] ?? 0;
        final patientAge = scan['patient_age'] ?? '';
        final patientGender = scan['patient_gender'] ?? '';
        final suspectedDisease = scan['suspected_disease'] ?? '';
        
        // Extract clinical_data JSON
        String symptoms = '';
        String notes = '';
        if (scan['clinical_data'] != null) {
          final clinicalData = scan['clinical_data'] as Map<String, dynamic>;
          if (clinicalData['checked_symptoms'] != null) {
            symptoms = (clinicalData['checked_symptoms'] as List).join('; ');
          }
          notes = clinicalData['additional_notes'] ?? '';
        }

        // Escape quotes in fields
        final escapedImageUrl = '"${imageUrl.replaceAll('"', '""')}"';
        final escapedSymptoms = '"${symptoms.replaceAll('"', '""')}"';
        final escapedNotes = '"${notes.replaceAll('"', '""')}"';

        csv.writeln('$id,$createdAt,$escapedImageUrl,$prediction,$confidence,$patientAge,$patientGender,$suspectedDisease,$escapedSymptoms,$escapedNotes');
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/eyevlm_export_$timestamp.csv');
      await file.writeAsString(csv.toString());

      if (mounted) {
        AppNotifications.showSuccess(context, 'Exported ${scans.length} records to:\n${file.path}');
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        AppNotifications.showError(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for manual refresh triggers (e.g. from SubmissionScreen)
    ref.listen<int>(historyRefreshProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        debugPrint("🔄 HistoryScreen: Refresh triggered via Provider!");
        _loadScans();
      }
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedScanIds.length} Selected')
            : Text(AppStrings.tr(ref, 'titleHistory')),
        leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedScanIds.clear();
                }),
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Selected Reports',
              onPressed: _selectedScanIds.isEmpty ? null : _downloadSelectedReports,
            ),
          ] else ...[
             // Replaced CSV Export with Selection Mode Toggle as per request
             IconButton(
                icon: const Icon(Icons.checklist_rtl),
                tooltip: 'Select Reports',
                onPressed: () {
                   setState(() => _isSelectionMode = true);
                },
             ),
          ],
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadScans();
            },
            child: _buildScansList(),
          ),
          
          if (_isDeleting || _isDownloading)
            Container(
              color: Colors.black.withAlpha(77),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// Build the scans list widget (replaces StreamBuilder)
  Widget _buildScansList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Filter out deleted scans
    final scans = _scans.where((s) => !_deletedIds.contains(s['id'].toString())).toList();
    
    if (scans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(AppStrings.tr(ref, 'noScansYet')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadScans,
              child: const Text("Refresh"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: scans.length,
      itemBuilder: (context, index) {
        final scan = scans[index];
        final visibleNumber = index + 1;
        final prediction = scan['prediction'] ?? 'Unknown';
        final isHealthy = prediction == 'Healthy';
        final confidence = scan['confidence'] != null 
            ? (scan['confidence'] * 100).toInt() 
            : 0;

        return Container(
          key: Key(scan['id'].toString()),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(26), 
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: () {
                // Enter selection mode on long press
                setState(() {
                  _isSelectionMode = true;
                  _selectedScanIds.add(scan['id'] is int ? scan['id'] : int.tryParse(scan['id'].toString()) ?? 0);
                });
              },
              onTap: () {
                if (_isSelectionMode) {
                  // Toggle selection
                  final scanId = scan['id'] is int ? scan['id'] : int.tryParse(scan['id'].toString()) ?? 0;
                  setState(() {
                    if (_selectedScanIds.contains(scanId)) {
                      _selectedScanIds.remove(scanId);
                      if (_selectedScanIds.isEmpty) {
                        _isSelectionMode = false;
                      }
                    } else {
                      _selectedScanIds.add(scanId);
                    }
                  });
                } else {
                  showHistoryDetails(
                    context, 
                    scan, 
                    (id, url) => showDeleteConfirmation(id, url, scan['prediction'] ?? 'Unknown'),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Selection checkbox
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Checkbox(
                          value: _selectedScanIds.contains(scan['id'] is int ? scan['id'] : int.tryParse(scan['id'].toString()) ?? 0),
                          onChanged: (val) {
                            final scanId = scan['id'] is int ? scan['id'] : int.tryParse(scan['id'].toString()) ?? 0;
                            setState(() {
                              if (val == true) {
                                _selectedScanIds.add(scanId);
                              } else {
                                _selectedScanIds.remove(scanId);
                                if (_selectedScanIds.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              }
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                      ),
                    // Image thumbnail - supports both local paths and URLs
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildThumbnail(scan),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Scan #$visibleNumber",
                            style: GoogleFonts.inter(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                prediction,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (scan['confidence'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isHealthy 
                                        ? Colors.green[50] 
                                        : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "$confidence%",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isHealthy 
                                          ? Colors.green 
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _downloadPdf(scan),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf, size: 16, color: Colors.teal.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  "Download Report",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal.shade700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
      },
    );
  }

  /// Build thumbnail widget supporting both local files and URLs
  Widget _buildThumbnail(Map<String, dynamic> scan) {
    final imageUrl = scan['image_url'] ?? '';
    
    // Check if it's a local file path
    if (!kIsWeb && imageUrl is String && imageUrl.startsWith('/')) {
      return Image.file(
        File(imageUrl),
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          height: 60, width: 60, 
          color: Colors.grey[200], 
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    
    // Network URL
    return Image.network(
      imageUrl,
      height: 60,
      width: 60,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        height: 60, width: 60, 
        color: Colors.grey[200], 
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Future<void> _downloadPdf(Map<String, dynamic> scan) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      if (!mounted) return;
      AppNotifications.showInfo(context, "Generating Report...");
      
      // Add timeout to prevent sticking
      await PdfService().generateAndShareReport(scan).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('PDF generation timed out'),
      );
      
      if (mounted) AppNotifications.showSuccess(context, "Report downloaded!");
    } catch (e) {
      if (mounted) AppNotifications.showError(context, "Failed to generate PDF: $e");
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Download reports for selected scans only
  Future<void> _downloadSelectedReports() async {
    if (_selectedScanIds.isEmpty) return;
    
    setState(() => _isDownloading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await Supabase.instance.client
          .from('scans')
          .select()
          .eq('user_id', userId)
          .inFilter('id', _selectedScanIds.toList());
      
      final scans = List<Map<String, dynamic>>.from(response);
      
      if (!mounted) return;
      AppNotifications.showInfo(context, "Generating ${scans.length} reports...");
      
      List<XFile> filesToShare = [];
      final pdfService = PdfService();

      int successCount = 0;
      for (final scan in scans) {
        try {
          final path = await pdfService.generateReportFile(scan);
          if (path != null) {
            filesToShare.add(XFile(path));
            successCount++;
          }
        } catch (e) {
          debugPrint("Failed to generate report ${scan['id']}: $e");
        }
      }
      
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedScanIds.clear();
        });

        if (filesToShare.isNotEmpty) {
           await Share.shareXFiles(
             filesToShare, 
             text: 'EyeVLM Batch Export ($successCount Reports)'
           );
           AppNotifications.showSuccess(context, "Reports generated!");
        } else {
           AppNotifications.showError(context, "No reports could be generated.");
        }
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, "Failed: $e");
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
