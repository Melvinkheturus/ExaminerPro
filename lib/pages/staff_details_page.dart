import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StaffDetailsPage extends StatefulWidget {
  final int staffCount;
  final int? initialPapers;
  final List<int>? initialPapersList;

  const StaffDetailsPage({
    super.key,
    required this.staffCount,
    this.initialPapers,
    this.initialPapersList,
  });

  @override
  _StaffDetailsPageState createState() => _StaffDetailsPageState();
}

class _StaffDetailsPageState extends State<StaffDetailsPage> {
  late List<TextEditingController> _controllers;
  final List<TextEditingController> _nameControllers = [];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.staffCount,
      (index) {
        String initialValue = '';
        if (widget.initialPapersList != null &&
            index < widget.initialPapersList!.length) {
          initialValue = widget.initialPapersList![index].toString();
        }
        return TextEditingController(text: initialValue);
      },
    );
    for (int i = 0; i < widget.staffCount; i++) {
      _nameControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validateInputs() {
    for (int i = 0; i < widget.staffCount; i++) {
      if (_nameControllers[i].text.isEmpty || _controllers[i].text.isEmpty) {
        return false;
      }
      final papers = int.tryParse(_controllers[i].text);
      if (papers == null || papers <= 0) {
        return false;
      }
    }
    return true;
  }

  void _saveAndReturn() {
    if (_validateInputs()) {
      // Create a list of paper counts
      final List<int> papersList =
          _controllers.map((controller) => int.parse(controller.text)).toList();

      // Return both total papers and individual counts
      Navigator.pop(context, {
        'total': papersList.reduce((a, b) => a + b), // Sum of all papers
        'papersList': papersList,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields with valid information'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );

    final textStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Details'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Staff Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.staffCount,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff ${index + 1}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameControllers[index],
                          style: textStyle,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Staff Name/ID',
                          ),
                          cursorColor: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[index],
                          style: textStyle,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Papers Evaluated',
                          ),
                          cursorColor: AppColors.primary,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saveAndReturn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
