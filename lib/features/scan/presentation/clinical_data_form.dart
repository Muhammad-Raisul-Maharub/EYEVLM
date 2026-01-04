import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eyevlm_app/core/widgets/responsive_wrapper.dart';

/// Clinical Data Form - Questionnaire for patient data collection.
/// This form appears after taking a photo with the Smart Camera.
class ClinicalDataForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final String? imagePath;
  
  const ClinicalDataForm({
    super.key, 
    required this.onSubmit,
    this.imagePath,
  });

  @override
  State<ClinicalDataForm> createState() => _ClinicalDataFormState();
}

class _ClinicalDataFormState extends State<ClinicalDataForm> {
  final _ageController = TextEditingController();
  String _gender = 'Male';
  String _suspectedDisease = 'Cataract';
  
  // The Symptom Checklist
  final Map<String, bool> _symptoms = {
    'Blurred Vision': false,
    'Redness / Irritation': false,
    'Eye Pain': false,
    'Light Sensitivity': false,
    'Double Vision': false,
  };
  
  final _notesController = TextEditingController();
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
                  child: Image.file(
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
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField(
                    value: _gender,
                    items: ['Male', 'Female', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _gender = v.toString()),
                    decoration: const InputDecoration(
                      labelText: "Gender", 
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text("2. Disease Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: _suspectedDisease,
              isExpanded: true,
              items: ['Cataract', 'Glaucoma', 'Diabetic Retinopathy', 'Conjunctivitis', 'Uveitis', 'Other']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _suspectedDisease = v.toString()),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 20),
            const Text("3. Symptoms (Check all that apply)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ..._symptoms.keys.map((key) => CheckboxListTile(
              title: Text(key),
              value: _symptoms[key],
              dense: true,
              activeColor: Colors.teal,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _symptoms[key] = v!),
            )),

            const SizedBox(height: 20),
            TextField(
              controller: _notesController, 
              maxLines: 3, 
              decoration: const InputDecoration(
                labelText: "Other Notes / History", 
                hintText: "E.g. history of surgery, diabetes, family history...",
                border: OutlineInputBorder(),
              ),
            ),

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
    );
  }

  void _submit() async {
    // Validate age
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age <= 0 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid age (1-120)")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Package the Checkboxes into JSON
    final clinicalJson = {
      'checked_symptoms': _symptoms.entries.where((e) => e.value).map((e) => e.key).toList(),
      'additional_notes': _notesController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await Future.value(widget.onSubmit({
        'patient_age': age,
        'patient_gender': _gender,
        'suspected_disease': _suspectedDisease,
        'clinical_data': clinicalJson, // Sent to JSONB column
      }));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
