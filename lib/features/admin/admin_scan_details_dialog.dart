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
  late TextEditingController _ageController;
  String? _gender;
  String? _suspectedDisease;
  Map<String, dynamic> _questionnaireAnswers = {};
  
  bool _isEditing = false;
  bool _isLoading = false;

  // Disease Categories (Matched with ClinicalDataForm)
  final List<String> _diseaseCategories = [
    'Cataracts', 'Uveitis', 'Pterygium', 'Keratitis', 
    'Conjunctivitis', 'Night Blindness', 'Ptosis', 'Other'
  ];

  // Questions List (Matched with ClinicalDataForm)
  final List<_AdminQuestion> _questions = [
    _AdminQuestion(1, "Gradual blurring or clouding of vision over time", "Cataract", false, ['Yes', 'No']),
    _AdminQuestion(2, "Seeing halos or starbursts around lights at night", "Cataract/Glaucoma", false, ['Yes', 'No']),
    _AdminQuestion(3, "Part of vision blocked by drooping eyelid", "Ptosis", false, ['Yes', 'No']),
    _AdminQuestion(4, "Sudden, severe vision loss in one eye", "Emergency/Uveitis", false, ['Yes', 'No']),
    _AdminQuestion(5, "Colors look faded, washed out, or yellowish", "Cataract", false, ['Yes', 'No']),
    _AdminQuestion(6, "Gritty, scratchy sensation (like sand in the eye)", "Conjunctivitis/Pterygium", false, ['Yes', 'No']),
    _AdminQuestion(7, "Deep, aching pain inside or behind the eye", "Uveitis", false, ['Yes', 'No']),
    _AdminQuestion(8, "Bright light hurts eyes significantly (Photophobia)", "Uveitis/Keratitis", false, ['Yes', 'No']),
    _AdminQuestion(9, "Severe surface pain making it hard to keep eye open", "Keratitis", false, ['Yes', 'No']),
    _AdminQuestion(10, "One or both eyes are visibly red/bloodshot", "Infection/Inflammation", false, ['Yes', 'No']),
    _AdminQuestion(11, "Fleshy growth on the white part of the eye", "Pterygium", false, ['Yes', 'No']),
    _AdminQuestion(12, "Discharge (pus, water, or mucus) leaking from eye", "Conjunctivitis", false, ['Yes', 'No']),
    _AdminQuestion(13, "White or grey spot on the colored part (cornea)", "Keratitis", false, ['Yes', 'No']),
    _AdminQuestion(14, "Regular contact lens wearer", "Risk Factor", false, ['Yes', 'No']),
    _AdminQuestion(15, "Have autoimmune disease (Arthritis, Lupus, etc.)", "Risk Factor", false, ['Yes', 'No']),
  ];

  @override
  void initState() {
    super.initState();
    _predictionController = TextEditingController(text: widget.scan['prediction'] ?? '');
    _symptomsController = TextEditingController(text: widget.scan['symptoms'] ?? '');
    _notesController = TextEditingController(text: widget.scan['notes'] ?? '');
    _confidenceController = TextEditingController(
      text: widget.scan['confidence']?.toString() ?? '0',
    );
    
    // Initialize new fields
    _ageController = TextEditingController(text: widget.scan['patient_age']?.toString() ?? '');
    _gender = widget.scan['patient_gender'] ?? 'Male';
    _suspectedDisease = widget.scan['suspected_disease'] ?? 'Cataracts';
    
    // Parse existing questionnaire answers from JSON
    if (widget.scan['clinical_data'] != null && widget.scan['clinical_data'] is Map) {
      final data = widget.scan['clinical_data'] as Map;
      if (data['questionnaire_answers'] != null) {
        _questionnaireAnswers = Map<String, dynamic>.from(data['questionnaire_answers']);
      }
    }
  }

  @override
  void dispose() {
    _predictionController.dispose();
    _symptomsController.dispose();
    _notesController.dispose();
    _confidenceController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final adminService = ref.read(adminServiceProvider);
      
      // Reconstruct Clinical Data JSON
      // Format symptoms list for display
      final List<String> formattedSymptoms = [];
      for (var q in _questions) {
        final key = "Q${q.id}";
        final ans = _questionnaireAnswers[key];
        if (ans == 'Yes' || (ans is List && ans.isNotEmpty)) {
           formattedSymptoms.add("${q.text}: $ans");
        }
      }
      
      // Merge with existing clinical data to preserve timestamp etc
      final Map<String, dynamic> existingClinical = 
        (widget.scan['clinical_data'] is Map) ? Map.from(widget.scan['clinical_data']) : {};
      
      existingClinical['questionnaire_answers'] = _questionnaireAnswers;
      existingClinical['checked_symptoms'] = formattedSymptoms;
      existingClinical['additional_notes'] = _notesController.text.trim();

      final updates = {
        'prediction': _predictionController.text.trim(),
        'symptoms': _symptomsController.text.trim(), // Legacy field, keeping in sync
        'notes': _notesController.text.trim(),
        'confidence': int.tryParse(_confidenceController.text.replaceAll('%', '').trim()) ?? 0,
        
        // New Fields
        'patient_age': int.tryParse(_ageController.text.trim()) ?? 0,
        'patient_gender': _gender,
        'suspected_disease': _suspectedDisease,
        'clinical_data': existingClinical,
      };

      final success = await adminService.updateScan(
        widget.scan['id'] as int,
        updates,
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
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
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
                              color: Colors.white.withOpacity(0.8),
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
                    // Images
                    if (imageUrls.isNotEmpty)
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(right: index < imageUrls.length - 1 ? 8 : 0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrls[index],
                                  width: 180, height: 180, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 180, height: 180, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    _buildInfoRow('User ID', userId.toString()),
                    const Divider(height: 24),

                    // --- EDITABLE FIELDS ---
                    Text("AI Analysis", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildEditableField(label: 'Prediction', controller: _predictionController, enabled: _isEditing)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildEditableField(label: 'Confidence (%)', controller: _confidenceController, enabled: _isEditing, keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text("Patient Details", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildEditableField(label: 'Age', controller: _ageController, enabled: _isEditing, keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: IgnorePointer(
                            ignoring: !_isEditing,
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: !_isEditing,
                                fillColor: !_isEditing ? Colors.grey[100] : null,
                              ),
                              items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    IgnorePointer(
                      ignoring: !_isEditing,
                      child: DropdownButtonFormField<String>(
                        value: _suspectedDisease,
                        decoration: InputDecoration(
                          labelText: 'Suspected Disease Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: !_isEditing,
                                fillColor: !_isEditing ? Colors.grey[100] : null,
                        ),
                        items: _diseaseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _suspectedDisease = v),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Text("Clinical Questionnaire", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    
                    // Questionnaire
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _questions.map((q) {
                          final answerKey = "Q${q.id}";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(child: Text("${q.id}. ${q.text}", style: const TextStyle(fontSize: 12))),
                                if (_isEditing)
                                  SizedBox(
                                    width: 120,
                                    child: SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'Yes', label: Text('Yes')),
                                        ButtonSegment(value: 'No', label: Text('No')),
                                      ],
                                      selected: { _questionnaireAnswers[answerKey] ?? 'No' },
                                      onSelectionChanged: (Set<String> newSelection) {
                                        setState(() {
                                          _questionnaireAnswers[answerKey] = newSelection.first;
                                        });
                                      },
                                      style: ButtonStyle(
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _questionnaireAnswers[answerKey] == 'Yes' ? Colors.red[50] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _questionnaireAnswers[answerKey] == 'Yes' ? Colors.red[200]! : Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      _questionnaireAnswers[answerKey] ?? 'No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _questionnaireAnswers[answerKey] == 'Yes' ? Colors.red[700] : Colors.grey[600],
                                        fontSize: 12
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildEditableField(label: 'Notes / History', controller: _notesController, enabled: _isEditing, maxLines: 3),
                  ],
                ),
              ),
            ),

            // Footer Actions
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

class _AdminQuestion {
  final int id;
  final String text;
  final String purpose;
  final bool isMultiSelect;
  final List<String> options;
  _AdminQuestion(this.id, this.text, this.purpose, this.isMultiSelect, this.options);
}
