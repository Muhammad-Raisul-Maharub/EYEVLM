import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_notifications.dart';
import '../../core/services/pdf_service.dart';
import 'admin_service.dart';

/// Dialog for viewing and editing scan details (Admin only)
class AdminScanDetailsDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> scan;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const AdminScanDetailsDialog({
    super.key,
    required this.scan,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  ConsumerState<AdminScanDetailsDialog> createState() => _AdminScanDetailsDialogState();
}

class _AdminScanDetailsDialogState extends ConsumerState<AdminScanDetailsDialog> {
  late TextEditingController _predictionController;
  late TextEditingController _symptomsController;
  late TextEditingController _notesController;
  late TextEditingController _confidenceController;
  
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _predictionController = TextEditingController(text: widget.scan['prediction'] ?? '');
    _symptomsController = TextEditingController(text: widget.scan['symptoms'] ?? '');
    _notesController = TextEditingController(text: widget.scan['notes'] ?? '');
    _confidenceController = TextEditingController(
      text: widget.scan['confidence']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _predictionController.dispose();
    _symptomsController.dispose();
    _notesController.dispose();
    _confidenceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final adminService = ref.read(adminServiceProvider);
      
      final success = await adminService.updateScan(
        widget.scan['id'] as int,
        {
          'prediction': _predictionController.text.trim(),
          'symptoms': _symptomsController.text.trim(),
          'notes': _notesController.text.trim(),
          'confidence': int.tryParse(_confidenceController.text) ?? 0,
        },
      );

      if (mounted) {
        if (success) {
          AppNotifications.showSuccess(context, 'Scan updated successfully');
          widget.onUpdate();
          Navigator.pop(context);
        } else {
          AppNotifications.showError(context, 'Failed to update scan');
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteScan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Scan'),
        content: const Text(
          'Are you sure you want to delete this scan? This will also delete all associated images. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final adminService = ref.read(adminServiceProvider);
      
      final success = await adminService.deleteScan(
        widget.scan['id'] as int,
        widget.scan['image_url'],
      );

      if (mounted) {
        if (success) {
          AppNotifications.showSuccess(context, 'Scan deleted successfully');
          widget.onDelete();
          Navigator.pop(context);
        } else {
          AppNotifications.showError(context, 'Failed to delete scan');
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _isLoading = true);
    try {
      if (mounted) {
         AppNotifications.showInfo(context, "Generating Report...");
      }
      
      // Use the PdfService to generate, save, and share data
      await PdfService().generateAndShareReport(widget.scan);
      
      if (mounted) {
        AppNotifications.showSuccess(context, "Report generated & shared!");
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Error generating PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(widget.scan['created_at'] ?? '');
    final imageUrl = widget.scan['image_url'] ?? '';
    final userId = widget.scan['user_id'] ?? 'Unknown';
    
    // Try to get multiple images
    List<String> imageUrls = [];
    if (widget.scan['image_urls'] != null) {
      try {
        imageUrls = List<String>.from(widget.scan['image_urls'] as List);
      } catch (_) {}
    }
    if (imageUrls.isEmpty && imageUrl.isNotEmpty) {
      imageUrls = [imageUrl];
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan #${widget.scan['id']}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image gallery
                    if (imageUrls.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < imageUrls.length - 1 ? 8 : 0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrls[index],
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 200,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported, size: 48),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // User ID
                    _buildInfoRow('User ID', userId.toString()),
                    const Divider(),

                    // Editable fields
                    _buildEditableField(
                      label: 'Prediction',
                      controller: _predictionController,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildEditableField(
                      label: 'Confidence (%)',
                      controller: _confidenceController,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildEditableField(
                      label: 'Symptoms',
                      controller: _symptomsController,
                      enabled: _isEditing,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildEditableField(
                      label: 'Notes',
                      controller: _notesController,
                      enabled: _isEditing,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Primary Actions Row
                        Row(
                          children: [
                             // Download Report (Prominent)
                             Expanded(
                               child: OutlinedButton.icon(
                                 onPressed: _downloadReport,
                                 icon: const Icon(Icons.picture_as_pdf, size: 20),
                                 label: const Text('Download Report', overflow: TextOverflow.ellipsis),
                                 style: OutlinedButton.styleFrom(
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                   alignment: Alignment.center,
                                 ),
                               ),
                             ),
                             const SizedBox(width: 8),
                             // Delete (Icon only to save space, or red text)
                             IconButton.filledTonal(
                               onPressed: _deleteScan,
                               icon: const Icon(Icons.delete, color: Colors.red),
                               style: IconButton.styleFrom(
                                 backgroundColor: Colors.red[50],
                               ),
                               tooltip: 'Delete Scan',
                             ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Edit / Save Row
                        if (_isEditing)
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => setState(() => _isEditing = false),
                                  style: TextButton.styleFrom(
                                     foregroundColor: Colors.grey[700],
                                     padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saveChanges,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Changes'),
                                  style: ElevatedButton.styleFrom(
                                     padding: const EdgeInsets.symmetric(vertical: 12),
                                     backgroundColor: Theme.of(context).primaryColor,
                                     foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Details'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: !enabled,
            fillColor: enabled ? null : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}
