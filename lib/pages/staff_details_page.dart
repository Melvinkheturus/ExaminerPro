import 'package:flutter/material.dart';

class StaffDetailsPage extends StatefulWidget {
  final int staffCount;
  final int? initialPapers;

  const StaffDetailsPage({
    super.key,
    required this.staffCount,
    this.initialPapers,
  });

  @override
  _StaffDetailsPageState createState() => _StaffDetailsPageState();
}

class _StaffDetailsPageState extends State<StaffDetailsPage> {
  final List<TextEditingController> _paperControllers = [];
  final List<TextEditingController> _nameControllers = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.staffCount; i++) {
      _paperControllers.add(TextEditingController(
          text: widget.initialPapers != null
              ? (widget.initialPapers! ~/ widget.staffCount).toString()
              : ''));
      _nameControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var controller in _paperControllers) {
      controller.dispose();
    }
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int _calculateTotalPapers() {
    int total = 0;
    for (var controller in _paperControllers) {
      final papers = int.tryParse(controller.text);
      if (papers != null) {
        total += papers;
      }
    }
    return total;
  }

  bool _validateInputs() {
    for (int i = 0; i < widget.staffCount; i++) {
      if (_nameControllers[i].text.isEmpty ||
          _paperControllers[i].text.isEmpty) {
        return false;
      }
      final papers = int.tryParse(_paperControllers[i].text);
      if (papers == null || papers <= 0) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Details'),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameControllers[index],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Staff Name/ID',
                            labelStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _paperControllers[index],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Papers Evaluated',
                            labelStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(),
                          ),
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
                  icon: const Icon(Icons.cancel),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    if (_validateInputs()) {
                      Navigator.pop(context, _calculateTotalPapers());
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please fill all fields with valid information'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
