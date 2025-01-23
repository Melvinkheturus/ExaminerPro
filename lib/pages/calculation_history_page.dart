import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../helpers/database_helper.dart';

class CalculationHistoryPage extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final int examinerId;

  const CalculationHistoryPage({
    super.key,
    required this.dbHelper,
    required this.examinerId,
  });

  @override
  State<CalculationHistoryPage> createState() => _CalculationHistoryPageState();
}

class _CalculationHistoryPageState extends State<CalculationHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedItems = {};
  bool _isSelectMode = false;
  final Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterHistory(String query) {
    setState(() {
      _filteredHistory = _history.where((record) {
        final date = DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(record['date']))
            .toLowerCase();
        final amount = record['total_salary'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return date.contains(searchQuery) || amount.contains(searchQuery);
      }).toList();
    });
  }

  Future<void> _loadHistory() async {
    final history = await widget.dbHelper.getCalculationHistory();
    setState(() {
      _history = history;
      _filteredHistory = history;
    });
  }

  Future<void> _deleteAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Calculation History'),
        content: const Text('Are you sure you want to delete all calculation history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.dbHelper.clearCalculationHistory();
      await _loadHistory();
    }
  }

  Future<void> _deleteCalculation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Calculation'),
        content: const Text('Are you sure you want to delete this calculation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.dbHelper.deleteCalculation(id);
      await _loadHistory();
    }
  }

  Future<void> _showCalculationDetails(Map<String, dynamic> record) async {
    final examiner = await widget.dbHelper.getExaminer(widget.examinerId);
    if (examiner != null) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Calculation Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date: ${DateFormat('dd/MM/yyyy').format(
                  DateTime.parse(record['date']),
                )}'),
                Text('Examiner: ${examiner['fullname']}'),
                Text('Department: ${examiner['department']}'),
                Text('Total Papers: ${record['papers_evaluated']}'),
                Text('Staff Count: ${record['staff_count']}'),
                Text('Base Salary: Rs.${record['base_salary'].toStringAsFixed(2)}'),
                Text('Incentive: Rs.${record['incentive_amount'].toStringAsFixed(2)}'),
                const Divider(),
                Text(
                  'Total Amount: Rs.${record['total_salary'].toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadSelected() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      final selectedCalculations = _filteredHistory
          .where((item) => _selectedItems.contains(item['id']))
          .toList();

      final examiner = await widget.dbHelper.getExaminer(selectedCalculations.first['examiner_id']);
      if (examiner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Examiner details not found')),
        );
        return;
      }

      for (var calculation in selectedCalculations) {
        pdf.addPage(await _generateCalculationPage(calculation, examiner));
      }

      final directory = await getApplicationDocumentsDirectory();
      final baseDir = Directory('${directory.path}/Chief Examiner');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final examinerDir = Directory('${baseDir.path}/${examiner['fullname']}');
      if (!await examinerDir.exists()) {
        await examinerDir.create();
      }

      final timestamp = DateFormat('ddMMyyyy_HHmm').format(DateTime.now());
      final fileName = '${examiner['fullname']}_SelectedCalculations_$timestamp.pdf';
      final file = File('${examinerDir.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      // Add to PDF history
      await widget.dbHelper.insertPdfHistory({
        'examiner_id': examiner['id'],
        'file_path': file.path,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  Future<void> _downloadAll() async {
    if (_filteredHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No calculations to download')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Group calculations by examiner
      final groupedCalculations = _groupHistoryByExaminer();
      
      // Add a cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'GURU NANAK COLLEGE (AUTONOMOUS)',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Complete Calculation History Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );

      // Add calculations grouped by examiner
      for (var entry in groupedCalculations.entries) {
        final examinerName = entry.key;
        final calculations = entry.value;
        final examiner = await widget.dbHelper.getExaminer(calculations.first['examiner_id']);
        
        if (examiner != null) {
          // Add examiner header page
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      examinerName,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Calculation History',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Add all calculations for this examiner
          for (var calculation in calculations) {
            pdf.addPage(await _generateCalculationPage(calculation, examiner));
          }
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final baseDir = Directory('${directory.path}/Chief Examiner/Overall Reports');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final timestamp = DateFormat('ddMMyyyy_HHmm').format(DateTime.now());
      final fileName = 'Complete_Calculation_History_$timestamp.pdf';
      final file = File('${baseDir.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      // Add to PDF history with special category
      await widget.dbHelper.insertPdfHistory({
        'examiner_id': 0,  // Special ID for overall reports
        'file_path': file.path,
        'created_at': DateTime.now().toIso8601String(),
        'is_overall_report': 1,  // New field to identify overall reports
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complete report saved to: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  Future<pw.Page> _generateCalculationPage(Map<String, dynamic> record, Map<String, dynamic> examiner) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'GURU NANAK COLLEGE (AUTONOMOUS)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Affiliated to University of Madras | Accredited \'A++\' Grade by NAAC',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'CONTROLLER OF EXAMINATIONS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'CHIEF EXAMINER SALARY REPORT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CHIEF EXAMINER DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(children: [pw.SizedBox(width: 100, child: pw.Text('Name')), pw.Text(': ${examiner['fullname']}')]),
                pw.Row(children: [pw.SizedBox(width: 100, child: pw.Text('ID')), pw.Text(': ${examiner['examinerid']}')]),
                pw.Row(children: [pw.SizedBox(width: 100, child: pw.Text('Department')), pw.Text(': ${examiner['department']}')]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CALCULATION DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Date'),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(record['date']))),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Total Staff'),
                  pw.Text('${record['staff_count']}'),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Papers Evaluated'),
                  pw.Text('${record['papers_evaluated']}'),
                ]),
                pw.Divider(),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Base Salary'),
                  pw.Text('Rs.${record['base_salary'].toStringAsFixed(2)}'),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Incentive Amount'),
                  pw.Text('Rs.${record['incentive_amount'].toStringAsFixed(2)}'),
                ]),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Net Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs.${record['total_salary'].toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupHistoryByExaminer() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var item in _filteredHistory) {
      final examinerName = item['examiner_name'] ?? 'Unknown Examiner';
      if (!grouped.containsKey(examinerName)) {
        grouped[examinerName] = [];
        _expandedGroups.putIfAbsent(examinerName, () => true);
      }
      grouped[examinerName]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search and Sort Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search calculations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterHistory,
            ),
          ),
          
          // Add Download Options Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Select/Cancel Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isSelectMode ? Icons.close : Icons.checklist,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isSelectMode ? 'Cancel' : 'Select',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSelectMode ? Colors.grey : const Color(0xFF6200EE),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isSelectMode = !_isSelectMode;
                        _selectedItems.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Download Selected Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      'Download Selected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: (!_isSelectMode || _selectedItems.isEmpty) ? null : _downloadSelected,
                  ),
                ),
                const SizedBox(width: 8),
                // Download All Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_for_offline, color: Colors.white),
                    label: const Text(
                      'Download All',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _filteredHistory.isEmpty ? null : _downloadAll,
                  ),
                ),
              ],
            ),
          ),
          
          // Calculation List
          Expanded(
            child: _filteredHistory.isEmpty
                ? const Center(child: Text('No calculation history found'))
                : ListView.builder(
                    itemCount: _groupHistoryByExaminer().length,
                    itemBuilder: (context, index) {
                      final groupedHistory = _groupHistoryByExaminer();
                      final examinerName = groupedHistory.keys.elementAt(index);
                      final examinerRecords = groupedHistory[examinerName]!;
                      
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            // Examiner Header
                            ListTile(
                              title: Text(
                                examinerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              leading: _isSelectMode
                                  ? Checkbox(
                                      value: examinerRecords.every(
                                        (record) => _selectedItems.contains(record['id'])),
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true) {
                                            for (var record in examinerRecords) {
                                              _selectedItems.add(record['id']);
                                            }
                                          } else {
                                            for (var record in examinerRecords) {
                                              _selectedItems.remove(record['id']);
                                            }
                                          }
                                        });
                                      },
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${examinerRecords.length} calculations',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _expandedGroups[examinerName]! 
                                          ? Icons.expand_less 
                                          : Icons.expand_more,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _expandedGroups[examinerName] = !_expandedGroups[examinerName]!;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Calculations List
                            if (_expandedGroups[examinerName]!)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: examinerRecords.length,
                                itemBuilder: (context, recordIndex) {
                                  final record = examinerRecords[recordIndex];
                                  final isSelected = _selectedItems.contains(record['id']);
                                  
                                  return ListTile(
                                    leading: _isSelectMode
                                        ? Checkbox(
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedItems.add(record['id']);
                                                } else {
                                                  _selectedItems.remove(record['id']);
                                                }
                                              });
                                            },
                                          )
                                        : null,
                                    title: Text(
                                      'Date: ${DateFormat('dd/MM/yyyy').format(
                                        DateTime.parse(record['date']),
                                      )}',
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total Papers: ${record['papers_evaluated']}'),
                                        Text('Total Staff: ${record['staff_count']}'),
                                        Text(
                                          'Total Salary: Rs.${record['total_salary'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6200EE),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: _isSelectMode
                                        ? null
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility),
                                                color: Colors.blue,
                                                onPressed: () => _showCalculationDetails(record),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                color: Colors.red,
                                                onPressed: () => _deleteCalculation(record['id']),
                                              ),
                                            ],
                                          ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: _deleteAllHistory,
        child: const Icon(Icons.delete_forever, color: Colors.black),
      ),
    );
  }
}
