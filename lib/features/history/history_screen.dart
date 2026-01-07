import 'dart:async';
import 'dart:io';
// Added: Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Added for animations
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/providers/refresh_provider.dart';
import '../../core/utils/app_notifications.dart'; // Import
import '../../core/services/pdf_service.dart';
import 'history_details_dialog.dart';
// Added: Printing

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Using a Stream ensures the list updates automatically when new scans are added
  // or items are deleted. This is crucial for tabs (IndexedStack).
  late Stream<List<Map<String, dynamic>>> _scansStream;
  bool _isDeleting = false;
  bool _isExporting = false;
  bool _isDownloading = false; // For download overlay
  // Keep track of auth subscription to cancel it
  late final StreamSubscription<AuthState> _authSubscription;
  final Set<int> _deletedIds = {}; // Local set for optimistic deletion
  
  // Selection mode state
  bool _isSelectionMode = false;
  final Set<int> _selectedScanIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize immediately
    _initStream();

    // Listen for Auth Changes (in case session restores late or user switches)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
       final event = data.event;
       if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
         _initStream();
       }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _initStream() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint("🔄 HistoryScreen: Initializing stream for User ID: $userId");

    if (userId != null) {
      if (mounted) {
        setState(() {
          _scansStream = Supabase.instance.client
              .from('scans')
              .stream(primaryKey: ['id'])
              .eq('user_id', userId)
              .order('created_at', ascending: false);
        });
      }
    } else {
       if (mounted) {
         setState(() {
            _scansStream = const Stream.empty();
         });
       }
    }
  }

  // Robust Delete Function - Deletes image, attachments, and database record
  Future<void> deleteScan(int scanId, String imageUrl) async {
    // Optimistic Update: Remove from UI immediately
    setState(() {
      _deletedIds.add(scanId); 
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
          _deletedIds.remove(scanId);
        });
        AppNotifications.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void showDeleteConfirmation(int scanId, String imageUrl, String prediction) {
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
        _initStream();
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
            if (!kIsWeb) // CSV export only on mobile (file access)
              IconButton(
                icon: _isExporting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                tooltip: 'Export to CSV',
                onPressed: _isExporting ? null : _exportToCSV,
              ),
          ],
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              _initStream();
              await Future.delayed(const Duration(seconds: 1));
            },
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _scansStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${snapshot.error}'),
                        ElevatedButton(onPressed: _initStream, child: const Text("Retry")),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: CircularProgressIndicator());
                }
              
              final allScans = snapshot.data ?? [];
              // Optimistically filter out items marked for deletion
              final scans = allScans.where((s) => !_deletedIds.contains(s['id'])).toList();
              
              if (scans.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                       const SizedBox(height: 16),
                       Text(AppStrings.tr(ref, 'noScansYet')),
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

                  // Removed Dismissible wrapper (delete only from detail view)
                  return Container(
                    key: Key(scan['id'].toString()),
                    child: Container(
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
                              _selectedScanIds.add(scan['id']);
                            });
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              // Toggle selection
                              setState(() {
                                if (_selectedScanIds.contains(scan['id'])) {
                                  _selectedScanIds.remove(scan['id']);
                                  if (_selectedScanIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  _selectedScanIds.add(scan['id']);
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
                                      value: _selectedScanIds.contains(scan['id']),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedScanIds.add(scan['id']);
                                          } else {
                                            _selectedScanIds.remove(scan['id']);
                                            if (_selectedScanIds.isEmpty) {
                                              _isSelectionMode = false;
                                            }
                                          }
                                        });
                                      },
                                      activeColor: Colors.teal,
                                    ),
                                  ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    scan['image_url'],
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c,e,s) => Container(
                                      height: 60, width: 60, 
                                      color: Colors.grey[200], 
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
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
                                // Delete button removed from list - available in detail view only
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
                },
              );
            },
          ),
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
      // Fetch the selected scans from the current stream data
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
      
      int successCount = 0;
      for (final scan in scans) {
        try {
          await PdfService().generateAndShareReport(scan);
          successCount++;
        } catch (e) {
          debugPrint("Failed to download report ${scan['id']}: $e");
        }
      }
      
      if (mounted) {
        AppNotifications.showSuccess(context, "Downloaded $successCount of ${scans.length} reports");
        setState(() {
          _isSelectionMode = false;
          _selectedScanIds.clear();
        });
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, "Failed to download reports: $e");
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
