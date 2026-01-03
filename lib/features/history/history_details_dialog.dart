import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';
import '../../core/services/pdf_service.dart';

void showHistoryDetails(BuildContext context, Map<String, dynamic> scan, Function(int, String) onDelete) {
  final DateTime date = DateTime.parse(scan['created_at']);
  final String formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal());
  final bool isHealthy = scan['prediction'] == 'Healthy';
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🖼️ 1. HEADER IMAGE
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    scan['image_url'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(
                      height: 200, 
                      color: Colors.grey[200], 
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
                // Close Button
                Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏷️ 2. STATUS BADGE & TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Analysis Result",
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                          ),
                          Text(
                            scan['prediction'],
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isHealthy ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isHealthy ? Colors.green.withAlpha(77) : Colors.orange.withAlpha(77),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 16,
                              color: isHealthy ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${(scan['confidence'] * 100).toInt()}% Confidence",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isHealthy ? Colors.green[700] : Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 30),

                  // 📝 3. DETAILS GRID
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: "Date Scanned",
                    value: formattedDate,
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.notes,
                    label: "Reported Symptoms",
                    value: (scan['symptoms'] == null || scan['symptoms'].isEmpty) 
                        ? "None reported" 
                        : scan['symptoms'],
                  ),

                  const SizedBox(height: 30),

                  // 🚀 4. ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Generate and Share PDF
                            PdfService().generateAndShareReport(
                              imageUrl: scan['image_url'],
                              prediction: scan['prediction'],
                              confidence: "${(scan['confidence'] * 100).toInt()}%",
                              symptoms: (scan['symptoms'] == null || scan['symptoms'].isEmpty) ? "None" : scan['symptoms'],
                              date: formattedDate,
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text("Download PDF"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Close popup first
                            Navigator.pop(context);
                            // Trigger Delete logic
                            onDelete(scan['id'], scan['image_url']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.delete),
                          label: const Text("Delete"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper Widget for neat rows
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF2D3748), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
