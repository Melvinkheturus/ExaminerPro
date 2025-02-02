import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../helpers/database_helper.dart';
import '../constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

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
  String _selectedSortOption = 'Date'; // Default sort option
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

  void _filterAndSortHistory(String query) {
    setState(() {
      _filteredHistory = _history.where((record) {
        final date = DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(record['date']))
            .toLowerCase();
        final amount = record['total_salary'].toString().toLowerCase();
        final examinerName = record['examiner_name'].toString().toLowerCase();
        return date.contains(query.toLowerCase()) ||
            amount.contains(query.toLowerCase()) ||
            examinerName.contains(query.toLowerCase());
      }).toList();

      _sortHistory();
    });
  }

  void _sortHistory() {
    setState(() {
      switch (_selectedSortOption) {
        case 'Date':
          _filteredHistory.sort((a, b) =>
              DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          break;
        case 'Amount':
          _filteredHistory.sort((a, b) =>
              (b['total_salary'] as num).compareTo(a['total_salary'] as num));
          break;
        case 'Name':
          _filteredHistory.sort((a, b) => (a['examiner_name'] as String)
              .compareTo(b['examiner_name'] as String));
          break;
      }
    });
  }

  Future<void> _loadHistory() async {
    final history = await widget.dbHelper.getCalculationHistory();
    setState(() {
      _history = history;
      _filteredHistory = List.from(history);
      _sortHistory(); // Apply initial sort
    });
  }

  Future<void> _deleteAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Calculation History'),
        content: const Text(
            'Are you sure you want to delete all calculation history? This cannot be undone.'),
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
        content:
            const Text('Are you sure you want to delete this calculation?'),
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

  Future<void> _downloadSelected([List<int>? specificIds]) async {
    final ids = specificIds ?? _selectedItems.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      final selectedCalculations =
          _filteredHistory.where((item) => ids.contains(item['id'])).toList();

      final examiner = await widget.dbHelper
          .getExaminer(selectedCalculations.first['examiner_id']);
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
      final fileName =
          '${examiner['fullname']}_SelectedCalculations_$timestamp.pdf';
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
    try {
      // Get all calculation history
      final history = await widget.dbHelper.getCalculationHistory();

      final pdf = pw.Document();

      // First page - Summary
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'GURU NANAK COLLEGE (AUTONOMOUS)',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Complete Calculation History Report',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'OVERALL CHIEF EXAMINER EVALUATION SUMMARY',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8), // Increased width for S.No
                  1: const pw.FlexColumnWidth(2.5), // Name
                  2: const pw.FlexColumnWidth(1.2), // Examiner ID
                  3: const pw.FlexColumnWidth(1.2), // Papers
                  4: const pw.FlexColumnWidth(1.5), // Base Salary
                  5: const pw.FlexColumnWidth(1.2), // Incentive
                  6: const pw.FlexColumnWidth(1.5), // Total Salary
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      'S.No',
                      'Name',
                      'Examiner ID',
                      'Papers',
                      'Base Salary',
                      'Incentive',
                      'Total Amt'
                    ]
                        .map((text) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                text,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 8),
                                textAlign: pw.TextAlign.center,
                              ),
                            ))
                        .toList(),
                  ),
                  // Data Rows
                  ...history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    return pw.TableRow(
                      children: [
                        (index + 1).toString(),
                        record['examiner_name'],
                        record['examinerid'],
                        record['total_papers'].toString(),
                        'Rs ${record['base_salary'].toStringAsFixed(0)}',
                        'Rs ${record['incentive_amount'].toStringAsFixed(0)}',
                        'Rs ${record['total_salary'].toStringAsFixed(0)}',
                      ]
                          .map((text) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 6),
                                child: pw.Text(
                                  text,
                                  style: const pw.TextStyle(fontSize: 10),
                                  textAlign: text.startsWith('Rs')
                                      ? pw.TextAlign.right
                                      : text.contains(RegExp(r'^\d+$'))
                                          ? pw.TextAlign.center
                                          : pw.TextAlign.left,
                                ),
                              ))
                          .toList(),
                    );
                  }),
                  // Total Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      'Total',
                      '-',
                      '-',
                      history
                          .fold<int>(
                              0, (sum, e) => sum + (e['total_papers'] as int))
                          .toString(),
                      'Rs ${history.fold<double>(0, (sum, e) => sum + (e['base_salary'] as double)).toStringAsFixed(0)}',
                      'Rs ${history.fold<double>(0, (sum, e) => sum + (e['incentive_amount'] as double)).toStringAsFixed(0)}',
                      'Rs ${history.fold<double>(0, (sum, e) => sum + (e['total_salary'] as double)).toStringAsFixed(0)}',
                    ]
                        .map((text) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                text,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10),
                                textAlign: text.startsWith('Rs')
                                    ? pw.TextAlign.right
                                    : text.contains(RegExp(r'^\d+$'))
                                        ? pw.TextAlign.center
                                        : text == 'Total'
                                            ? pw.TextAlign.left
                                            : pw.TextAlign.center,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'This is a system-generated summary. For detailed calculations, refer to the next page.',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Add detailed report pages
      for (var calculation in history) {
        final examiner =
            await widget.dbHelper.getExaminer(calculation['examiner_id']);
        if (examiner != null) {
          pdf.addPage(await _generateCalculationPage(calculation, examiner));
        }
      }

      // Save and open PDF
      final prefs = await SharedPreferences.getInstance();
      String? customLocation = prefs.getString('pdf_save_location');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'overall_evaluation_report_$timestamp.pdf';

      String filePath;
      if (customLocation != null && customLocation.isNotEmpty) {
        // Use custom location
        customLocation = customLocation.replaceAll('\\', '/');
        final saveDir = Directory(customLocation);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        filePath = p.join(customLocation, fileName);
        if (Platform.isWindows) {
          filePath = filePath.replaceAll('/', '\\');
        }
      } else {
        // Use default location
        final directory = await getApplicationDocumentsDirectory();
        final baseDir =
            Directory('${directory.path}/Chief Examiner/Overall Reports');
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
        filePath = p.join(baseDir.path, fileName);
      }

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Add to PDF history with special category
      await widget.dbHelper.insertPdfHistory({
        'examiner_id': 0, // Special ID for overall reports
        'file_path': file.path,
        'created_at': DateTime.now().toIso8601String(),
        'is_overall_report': 1, // New field to identify overall reports
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
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  Future<pw.Page> _generateCalculationPage(
      Map<String, dynamic> record, Map<String, dynamic> examiner) async {
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
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Affiliated to University of Madras | Accredited \'A++\' Grade by NAAC',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'CONTROLLER OF EXAMINATIONS',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'CHIEF EXAMINER SALARY REPORT',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
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
                pw.Text('CHIEF EXAMINER DETAILS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(children: [
                  pw.SizedBox(width: 100, child: pw.Text('Name')),
                  pw.Text(': ${examiner['fullname']}')
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 100, child: pw.Text('ID')),
                  pw.Text(': ${examiner['examinerid']}')
                ]),
                pw.Row(children: [
                  pw.SizedBox(width: 100, child: pw.Text('Department')),
                  pw.Text(': ${examiner['department']}')
                ]),
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
                pw.Text('CALCULATION DETAILS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Date'),
                      pw.Text(DateFormat('dd/MM/yyyy')
                          .format(DateTime.parse(record['date']))),
                    ]),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Staff'),
                      pw.Text('${record['total_staff']}'),
                    ]),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Papers Evaluated'),
                      pw.Text('${record['total_papers']}'),
                    ]),
                pw.Divider(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Base Salary'),
                      pw.Text('Rs.${record['base_salary'].toStringAsFixed(2)}'),
                    ]),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Incentive Amount'),
                      pw.Text(
                          'Rs.${record['incentive_amount'].toStringAsFixed(2)}'),
                    ]),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Net Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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

  void _viewCalculation(Map<String, dynamic> calculation) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7, // Make dialog wider
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calculation Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Examiner: ${calculation['examiner_name']}'),
                        Text('ID: ${calculation['examinerid']}'),
                        Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(calculation['date']))}'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Papers: ${calculation['total_papers']}'),
                        Text('Total Staff: ${calculation['total_staff']}'),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Base Salary: Rs.${calculation['base_salary'].toStringAsFixed(2)}'),
                        Text(
                            'Incentive: Rs.${calculation['incentive_amount'].toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Total Amount: Rs.${calculation['total_salary'].toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                    onPressed: () {
                      Navigator.pop(context);
                      _downloadSelected([calculation['id']]);
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Search and Sort Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search calculations...',
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    cursorColor: AppColors.primary,
                    onChanged: _filterAndSortHistory,
                  ),
                ),
                const SizedBox(width: 8),

                // Sort Icon with Dropdown Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, size: 28),
                  tooltip: 'Sort by',
                  onSelected: (String newValue) {
                    setState(() {
                      _selectedSortOption = newValue;
                      _sortHistory();
                    });
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'Date',
                      child: Text('Sort by Date'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'Amount',
                      child: Text('Sort by Amount'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'Name',
                      child: Text('Sort by Name'),
                    ),
                  ],
                ),
              ],
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
                      backgroundColor:
                          _isSelectMode ? Colors.grey : AppColors.primary,
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
                    onPressed: (!_isSelectMode || _selectedItems.isEmpty)
                        ? null
                        : _downloadSelected,
                  ),
                ),
                const SizedBox(width: 8),
                // Download All Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_for_offline,
                        color: Colors.white),
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
                                      value: examinerRecords.every((record) =>
                                          _selectedItems
                                              .contains(record['id'])),
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true) {
                                            for (var record
                                                in examinerRecords) {
                                              _selectedItems.add(record['id']);
                                            }
                                          } else {
                                            for (var record
                                                in examinerRecords) {
                                              _selectedItems
                                                  .remove(record['id']);
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
                                        _expandedGroups[examinerName] =
                                            !_expandedGroups[examinerName]!;
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
                                  final isSelected =
                                      _selectedItems.contains(record['id']);

                                  return ListTile(
                                    leading: _isSelectMode
                                        ? Checkbox(
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedItems
                                                      .add(record['id']);
                                                } else {
                                                  _selectedItems
                                                      .remove(record['id']);
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Total Papers: ${record['total_papers']}'),
                                        Text(
                                            'Total Staff: ${record['total_staff']}'),
                                        Text(
                                          'Total Salary: Rs.${record['total_salary'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
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
                                                icon: const Icon(
                                                    Icons.visibility),
                                                onPressed: () =>
                                                    _viewCalculation(record),
                                                tooltip: 'View Details',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                color: Colors.red,
                                                onPressed: () =>
                                                    _deleteCalculation(
                                                        record['id']),
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
