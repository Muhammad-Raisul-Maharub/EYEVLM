import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/providers/refresh_provider.dart';
import 'history_details_dialog.dart';

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
  // Keep track of auth subscription to cancel it
  late final StreamSubscription<AuthState> _authSubscription;
  final Set<int> _deletedIds = {}; // Local set for optimistic deletion

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
              .order('created_at', ascending: true);
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

  // Robust Delete Function (Exact implementation from user request)
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
      // We parse the URL to find the path *after* the bucket name ('eye-images')
      final bucketIndex = segments.indexOf('eye-images');

      if (bucketIndex == -1) {
        throw Exception("Invalid URL: 'eye-images' bucket not found.");
      }

      // Join all segments after the bucket name to get the full storage path
      // Example: converts ["...","eye-images", "folder", "scan.jpg"] -> "folder/scan.jpg"
      final filePath = segments.sublist(bucketIndex + 1).join('/');

      debugPrint("Targeting file for deletion: $filePath"); // Debug print

      // --- 2. Delete from Storage ---
      final List<FileObject> result = await supabase
          .storage
          .from('eye-images')
          .remove([filePath]);

      // Check if storage delete actually happened
      if (result.isEmpty) {
        debugPrint("⚠️ Warning: Storage file not found or policy blocked deletion.");
      } else {
        debugPrint("✅ Storage file deleted successfully.");
      }

      // --- 3. Delete from Database ---
      await supabase.from('scans').delete().eq('id', scanId);

      // --- 4. Update UI ---
      // We are using StreamBuilder, so the UI updates automatically.
      // If we were using a manual List, we would use:
      // setState(() { scans.removeWhere((item) => item['id'] == scanId); });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      debugPrint("Error during deletion: $e");
      // Revert Optimistic Update
      if (mounted) {
        setState(() {
          _deletedIds.remove(scanId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${scans.length} records to:\n${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
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
        title: Text(AppStrings.tr(ref, 'titleHistory')),
        actions: [
          if (!kIsWeb) // CSV export only on mobile (file access)
            IconButton(
              icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              tooltip: 'Export to CSV',
              onPressed: _isExporting ? null : _exportToCSV,
            ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _scansStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
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

                  return Dismissible(
                    key: Key(scan['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white, size: 28),
                    ),
                    confirmDismiss: (direction) async {
                       showDeleteConfirmation(
                          scan['id'], 
                          scan['image_url'], 
                          scan['prediction'] ?? 'Unknown',
                        );
                        return false;
                    },
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
                          onTap: () {
                            showHistoryDetails(
                              context, 
                              scan, 
                              (id, url) => showDeleteConfirmation(id, url, scan['prediction'] ?? 'Unknown'),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
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
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => showDeleteConfirmation(
                                    scan['id'], 
                                    scan['image_url'], 
                                    scan['prediction'] ?? 'Unknown',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          if (_isDeleting)
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
}
