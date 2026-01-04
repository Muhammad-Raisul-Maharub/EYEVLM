import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:eyevlm_app/core/widgets/responsive_wrapper.dart';
import 'package:eyevlm_app/core/utils/app_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clinical Data Form - Questionnaire for patient data collection.
/// This form appears after taking a photo with the Smart Camera.
class ClinicalDataForm extends StatefulWidget {
  final Function(Map<String, dynamic>, List<PlatformFile>?) onSubmit;
  final String? imagePath;
  final Uint8List? imageBytes; // Added for Web
  
  const ClinicalDataForm({
    super.key, 
    required this.onSubmit,
    this.imagePath,
    this.imageBytes,
  });

  @override
  State<ClinicalDataForm> createState() => _ClinicalDataFormState();
}

class _ClinicalDataFormState extends State<ClinicalDataForm> {
  final _ageController = TextEditingController();
  
  String _gender = 'Male';
  String _suspectedDisease = 'Cataracts';
  
  // Updated Disease Categories based on new requirement
  final List<String> _diseaseCategories = [
    'Cataracts',
    'Uveitis', 
    'Pterygium', 
    'Keratitis', 
    'Conjunctivitis', 
    'Night Blindness', 
    'Ptosis', 
    'Other'
  ];

  // Questionnaire State
  // Map<QuestionID, SelectedValue(s)>
  // Value is String for SingleSelect, List<String> for MultiSelect
  final Map<int, dynamic> _answers = {};

  final _notesController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Clinical Context")),
      body: ResponsiveWrapper(
        mobileBody: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Image preview if available
            if (widget.imagePath != null) ...[
              const Text("Captured Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withAlpha(100)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.imageBytes != null
                      ? Image.memory(
                          widget.imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        )
                      : Image.file(
                          File(widget.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const Text("1. Patient Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(
                      labelText: "Age", 
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField(
                    initialValue: _gender,
                    items: ['Male', 'Female', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _gender = v.toString()),
                    decoration: const InputDecoration(
                      labelText: "Gender", 
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text("2. Disease Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              initialValue: _suspectedDisease,
              isExpanded: true,
              items: _diseaseCategories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _suspectedDisease = v.toString()),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),

            const SizedBox(height: 20),
            const Text("3. Symptom Checker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              "Please answer the following questions to help AI analyze the condition.",
              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),

            // Render Questions
            ..._questions.map((q) => _buildQuestionCard(q)),

            const SizedBox(height: 20),
            const Text("4. Additional Context", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController, 
              maxLines: 3, 
              decoration: const InputDecoration(
                labelText: "Other Notes / History", 
                hintText: "E.g. history of surgery, diabetes, family history...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            const Text("5. Medical Records (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file, color: Colors.teal),
              label: const Text("Attach Reports/History (PDF, IMG)", style: TextStyle(color: Colors.teal)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade50,
                elevation: 0,
                side: const BorderSide(color: Colors.teal),
              ),
            ),
            if (_attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._attachedFiles.map((file) => ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${(file.size / 1024).toStringAsFixed(1)} KB'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _attachedFiles.remove(file)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), 
                dense: true,
              )),
            ],

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: _isLoading 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Submit Analysis", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildQuestionCard(_Question q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Q${q.id}: ${q.text}",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              q.purpose, // Showing purpose as subtitle helps user
              style: GoogleFonts.inter(fontSize: 12, color: Colors.teal.shade700, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            if (q.isMultiSelect)
              ...q.options.map((opt) {
                final List<String> current = (_answers[q.id] as List<String>?) ?? [];
                final isSelected = current.contains(opt);
                return CheckboxListTile(
                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                  value: isSelected,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.teal,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) {
                    setState(() {
                      final list = List<String>.from(current);
                      if (val == true) {
                        list.add(opt);
                      } else {
                        list.remove(opt);
                      }
                      _answers[q.id] = list;
                    });
                  },
                );
              })
            else
              ...q.options.map((opt) {
                return RadioListTile<String>(
                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                  value: opt,
                  groupValue: _answers[q.id] as String?,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      _answers[q.id] = val;
                    });
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true, 
      );
      if (result != null) {
        setState(() {
          _attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, "Error picking files: $e");
      }
    }
  }

  void _submit() async {
    // Validate age
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age <= 0 || age > 120) {
      AppNotifications.showError(context, "Please enter a valid age (1-120)");
      return;
    }

    setState(() => _isLoading = true);
    
    // Package Responses
    // Format: "Q1: Answer" for better readability in simple views
    final List<String> formattedSymptoms = [];
    for (var q in _questions) {
      final ans = _answers[q.id];
      if (ans != null) {
        if (ans is List && ans.isNotEmpty) {
           formattedSymptoms.add("${q.text}: ${ans.join(', ')}");
        } else if (ans is String && ans.isNotEmpty) {
           formattedSymptoms.add("${q.text}: $ans");
        }
      }
    }

    final clinicalJson = {
      'questionnaire_answers': _answers.map((k, v) => MapEntry("Q$k", v)), // Raw data
      'checked_symptoms': formattedSymptoms, // Backward compatibility & Display
      'additional_notes': _notesController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await Future.value(widget.onSubmit({
        'patient_age': age,
        'patient_gender': _gender,
        'suspected_disease': _suspectedDisease,
        'clinical_data': clinicalJson, 
      }, _attachedFiles));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- QUESTION DATA ---
  final List<_Question> _questions = [
    _Question(1, "Nature of Vision Change", "Distinguishes refractive errors from blockage.", false, [
      "Blurry, cloudy, or foggy overall",
      "Part of vision blocked (curtain/eyelid)",
      "Lost side or central vision",
      "No significant changes"
    ]),
    _Question(2, "Night Vision & Light", "Screens for Night Blindness vs Glare.", true, [
      "Night Blindness (struggle in dim light)",
      "Glare/Halos around lights",
      "Photophobia (light hurts eyes)",
      "None of these"
    ]),
    _Question(3, "Pain Characteristics", "Differentiates Surface vs Deep issues.", false, [
      "Gritty/Sand-like (scratching)",
      "Deep Ache (throbbing behind eye)",
      "Sharp/Stabbing (severe surface pain)",
      "No Pain (only discomfort)"
    ]),
    _Question(4, "Redness Pattern", "Distinguishes Infection from Inflammation.", false, [
      "One Eye Only",
      "Both Eyes",
      "No Redness"
    ]),
    _Question(5, "Discharge & Tearing", "Identifies infection type.", false, [
      "Watery (excessive clear tears)",
      "Pus/Thick (yellow/green/crusty)",
      "Stringy (white/mucus-like)",
      "Dry/None"
    ]),
    _Question(6, "Visible Physical Anomalies", "Detects Pterygium, Ptosis, Ulcers.", true, [
      "Growth (fleshy/triangular)",
      "Drooping Eyelid(s)",
      "White Spot on Cornea",
      "None"
    ]),
    _Question(7, "Onset & Duration", "Urgency Triage.", false, [
      "Sudden (hours to days)",
      "Gradual (weeks/months/years)"
    ]),
    _Question(8, "Trauma & Foreign Body", "Check for injury.", false, [
      "Yes (injury, surgery, poke)",
      "No injury or trauma"
    ]),
    _Question(9, "Color & Distortion", "Secondary symptom check.", false, [
      "Colors faded/yellowish",
      "Straight lines look wavy",
      "No change"
    ]),
    _Question(10, "Risk Factors", "Connects symptoms to causes.", true, [
      "Contact Lenses",
      "Autoimmune Disease",
      "Diabetes / High BP",
      "None"
    ]),
  ];
}

class _Question {
  final int id;
  final String text;
  final String purpose;
  final bool isMultiSelect;
  final List<String> options;

  _Question(this.id, this.text, this.purpose, this.isMultiSelect, this.options);
}
