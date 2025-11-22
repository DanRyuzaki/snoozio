import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CarePlanUploadScreen extends StatefulWidget {
  const CarePlanUploadScreen({super.key});

  @override
  State<CarePlanUploadScreen> createState() => _CarePlanUploadScreenState();
}

class _CarePlanUploadScreenState extends State<CarePlanUploadScreen> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();

  final List<Map<String, String>> _activities = [];
  bool _isUploading = false;

  void _addActivity() {
    setState(() {
      _activities.add({'time': '', 'activity': ''});
    });
  }

  void _removeActivity(int index) {
    setState(() {
      _activities.removeAt(index);
    });
  }

  Future<void> _uploadPlan() async {
    if (_categoryController.text.isEmpty ||
        _versionController.text.isEmpty ||
        _dayController.text.isEmpty ||
        _activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields and at least 1 activity required!'),
        ),
      );
      return;
    }

    try {
      setState(() => _isUploading = true);

      final data = {
        'day': _dayController.text.trim(),
        'activities': _activities
            .map(
              (a) => {'time': a['time'] ?? '', 'activity': a['activity'] ?? ''},
            )
            .toList(),
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('care_plans')
          .doc(_categoryController.text.trim().toLowerCase())
          .collection(_versionController.text.trim().toLowerCase())
          .doc(_dayController.text.trim().toLowerCase())
          .set(data);

      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Care Plan uploaded successfully!')),
        );
      }

      _categoryController.clear();
      _versionController.clear();
      _dayController.clear();
      _activities.clear();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload Care Plan",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              _buildTextField(
                _categoryController,
                "Category (e.g. mild, moderate, severe)",
              ),
              const SizedBox(height: 16),
              _buildTextField(_versionController, "Version (e.g. v1, v2)"),
              const SizedBox(height: 16),
              _buildTextField(_dayController, "Day (e.g. day_1, day_2)"),
              const SizedBox(height: 24),

              const Text(
                "Activities",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              ..._activities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Time (e.g. 8:00 AM)",
                        ),
                        onChanged: (val) => activity['time'] = val,
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Activity Description",
                        ),
                        onChanged: (val) => activity['activity'] = val,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeActivity(index),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Activity"),
                onPressed: _addActivity,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  side: BorderSide(color: Colors.deepPurple.shade200),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isUploading ? null : _uploadPlan,
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Upload Plan"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepPurple.shade300),
        ),
      ),
    );
  }
}
