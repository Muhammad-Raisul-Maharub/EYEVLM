import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
// Conditional import for web
import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart' as pdf_download;

/// Service to generate PDF reports for EyeVLM scans.
class PdfService {
  /// Generates a PDF document for a single scan record.
  Future<Uint8List> generateScanReport({
    required Map<String, dynamic> scanData,
    Uint8List? scanImageBytes,
    String? patientName,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    // Extract Data
    final prediction = scanData['prediction'] ?? 'Unknown';
    final confidence = (scanData['confidence'] ?? 0.0) * 100;
    final date = DateTime.tryParse(scanData['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy - h:mm a').format(date);
    
    // Clinical Data
    final clinicalData = scanData['clinical_data'] as Map<String, dynamic>? ?? {};
    final checkedSymptoms = (clinicalData['checked_symptoms'] as List?)?.join(', ') ?? 'None';
    final additionalNotes = clinicalData['additional_notes'] ?? 'None';
    final attachments = (clinicalData['attachments'] as List?) ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('EyeVLM Medical Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Text('Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Patient / Scan Info
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRow('Scan ID:', (scanData['id'].toString().length > 8) ? scanData['id'].toString().substring(0, 8) : scanData['id'].toString(), boldFont),
                    pw.SizedBox(height: 5),
                    _buildRow('Date:', formattedDate, boldFont),
                    pw.SizedBox(height: 5),
                    _buildRow('Patient Age:', '${scanData['patient_age'] ?? "N/A"}', boldFont),
                    pw.SizedBox(height: 5),
                    _buildRow('Gender:', '${scanData['patient_gender'] ?? "N/A"}', boldFont),
                    pw.SizedBox(height: 5),
                    _buildRow('Suspected Condition:', '${scanData['suspected_disease'] ?? "N/A"}', boldFont),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // AI Analysis Result
              pw.Text('AI Analysis Result', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text('Prediction:', style: pw.TextStyle(fontSize: 16)),
                   pw.Text(prediction, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: prediction == 'Healthy' ? PdfColors.green : PdfColors.red)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text('Confidence:', style: pw.TextStyle(fontSize: 16)),
                   pw.Text('${confidence.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),

              // Scan Image
              if (scanImageBytes != null)
                pw.Center(
                  child: pw.Container(
                    height: 200,
                    width: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    child: pw.Image(pw.MemoryImage(scanImageBytes), fit: pw.BoxFit.cover),
                  ),
                ),
              pw.SizedBox(height: 20),

              // Clinical Notes
              pw.Text('Clinical Context', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(color: PdfColors.grey300),
              _buildRow('Reported Symptoms:', checkedSymptoms, boldFont),
              pw.SizedBox(height: 10),
              pw.Text('Additional Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(additionalNotes),
              pw.SizedBox(height: 20),

              // Attachments List
              if (attachments.isNotEmpty) ...[
                 pw.Text('Attached Files', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                 pw.Divider(color: PdfColors.grey300),
                 ...attachments.map((file) => pw.UrlLink(
                   destination: file['url'],
                   child: pw.Text('- ${file['name']} (Click to View)', style: const pw.TextStyle(color: PdfColors.blue, decoration: pw.TextDecoration.underline)),
                 )),
              ],

              pw.Spacer(),
              pw.Center(child: pw.Text('EyeVLM - AI Assisted Ophthalmology Tool', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildRow(String label, String value, pw.Font boldFont) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(font: boldFont))),
        pw.Expanded(child: pw.Text(value)),
      ],
    );
  }

  /// Downloads PDF - saves to Downloads folder on Android, share sheet on iOS
  /// Returns the file path if saved to storage, null if shared via sheet
  Future<String?> downloadPdf(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      pdf_download.downloadPdfWeb(bytes, filename);
      return null;
    }
    
    // On Android, try to save directly to Downloads folder
    if (Platform.isAndroid) {
      try {
        // Check/request storage permission for older Android versions
        PermissionStatus status;
        if (await Permission.manageExternalStorage.isGranted) {
          status = PermissionStatus.granted;
        } else {
          // Try regular storage permission first (for Android < 11)
          status = await Permission.storage.request();
          if (!status.isGranted) {
            // For Android 11+, try manage external storage
            status = await Permission.manageExternalStorage.request();
          }
        }
        
        if (status.isGranted || await Permission.storage.isGranted) {
          // Save to Downloads folder
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            final file = File('${downloadsDir.path}/$filename');
            await file.writeAsBytes(bytes);
            debugPrint("✅ PDF saved to: ${file.path}");
            return file.path;
          }
        }
        
        // Fallback: Save to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$filename');
        await file.writeAsBytes(bytes);
        debugPrint("✅ PDF saved to app folder: ${file.path}");
        return file.path;
      } catch (e) {
        debugPrint("⚠️ Could not save PDF: $e");
        // Fallback to share sheet
      }
    }
    
    // Fallback for iOS or if storage fails: use share sheet
    await Printing.sharePdf(bytes: bytes, filename: filename);
    return null;
  }

  /// Convenience method to generate and download the report.
  /// Fetches the scan image from Supabase Storage if available.
  Future<void> generateAndShareReport(Map<String, dynamic> scan) async {
    Uint8List? imageBytes;
    
    // Attempt to fetch image if URL exists
    if (scan['image_url'] != null) {
      try {
        final String imageUrl = scan['image_url'];
        final uri = Uri.parse(imageUrl);
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf('eye-images');
        
        if (bucketIndex != -1) {
             final storagePath = segments.sublist(bucketIndex + 1).join('/');
             final response = await Supabase.instance.client.storage.from('eye-images').download(storagePath);
             imageBytes = response;
        }
      } catch (e) {
        debugPrint("⚠️ PdfService: Could not fetch image for PDF: $e");
      }
    }
    
    final bytes = await generateScanReport(scanData: scan, scanImageBytes: imageBytes);
    final name = 'EyeVLM_Report_${(scan['id'].toString().length > 8) ? scan['id'].toString().substring(0, 8) : scan['id']}.pdf';
    await downloadPdf(bytes, name);
  }
}
