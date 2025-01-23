import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'staff_details_page.dart';
import '../helpers/database_helper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class EvaluationDay {
  final DateTime date;
  final int staffCount;
  final int papersEvaluated;

  EvaluationDay({
    required this.date,
    required this.staffCount,
    required this.papersEvaluated,
  });
}

class CalculationPage extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final Map<String, dynamic> examiner;

  const CalculationPage({
    super.key,
    required this.examiner,
    required this.dbHelper,
  });

  @override
  _CalculationPageState createState() => _CalculationPageState();
}

class _CalculationPageState extends State<CalculationPage> {
  final List<EvaluationDay> _evaluationDays = [];
  final _staffCountController = TextEditingController();
  DateTime? _selectedDate;
  double _totalSalary = 0;
  double _baseSalary = 0;
  double _incentiveAmount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chief Examiner Calculator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6200EE),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. CHIEF EXAMINER SECTION
                Container(
                  margin: const EdgeInsets.only(bottom: 30),
                  width: double.infinity,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: const Color(0xFF6200EE),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      child: Column(
                        children: [
                          const Text(
                            'CHIEF EXAMINER',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.examiner['fullname'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6200EE),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. EVALUATION SCHEDULE SECTION
                Container(
                  margin: const EdgeInsets.only(bottom: 30),
                  width: double.infinity,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'EVALUATION SCHEDULE',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 60,
                                  child: TextButton.icon(
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 28,
                                      color: Color(0xFF6200EE),
                                    ),
                                    label: Text(
                                      _selectedDate == null
                                          ? 'Select Date'
                                          : DateFormat('dd/MM/yyyy')
                                              .format(_selectedDate!),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF6200EE),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.grey[100],
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: const BorderSide(
                                            color: Color(0xFF6200EE)),
                                      ),
                                    ),
                                    onPressed: _selectDate,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 60,
                                  child: TextField(
                                    controller: _staffCountController,
                                    decoration: InputDecoration(
                                      labelText: 'Number Of Examiners',
                                      labelStyle: const TextStyle(
                                        fontSize: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 20,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                              height: 60,
                              child: ElevatedButton.icon(
                                icon:
                                    const Icon(Icons.add, color: Colors.white),
                                label: const Text(
                                  'Add Another Day',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6200EE),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                  shadowColor: Colors.black.withAlpha(77),
                                ).copyWith(
                                  elevation:
                                      WidgetStateProperty.resolveWith<double>(
                                    (Set<WidgetState> states) {
                                      if (states
                                          .contains(WidgetState.hovered)) {
                                        return 4;
                                      }
                                      return 2;
                                    },
                                  ),
                                ),
                                onPressed: _addStaffDetails,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. EVALUATION SUMMARY TABLE
                if (_evaluationDays.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 30),
                    width: double.infinity,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'EVALUATION SUMMARY',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6200EE),
                                ),
                                dataTextStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Staff Count')),
                                  DataColumn(label: Text('Papers')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _evaluationDays.map((day) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(day.date),
                                      )),
                                      DataCell(Text(day.staffCount.toString())),
                                      DataCell(
                                          Text(day.papersEvaluated.toString())),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              color: const Color(0xFF6200EE),
                                              onPressed: () => _editDay(day),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              onPressed: () => _removeDay(day),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. CALCULATE & REFRESH BUTTONS
                Container(
                  margin: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon:
                              const Icon(Icons.calculate, color: Colors.white),
                          label: const Text(
                            'Calculate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6200EE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            minimumSize: const Size.fromHeight(60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _calculateSalary,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon:
                              const Icon(Icons.refresh, color: Colors.black87),
                          label: const Text(
                            'Refresh',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            minimumSize: const Size.fromHeight(60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _refresh,
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. CALCULATION RESULTS
                if (_totalSalary > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 30),
                    width: double.infinity,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'CALCULATION RESULTS',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ResultRow(
                              label: 'Total Papers Evaluated',
                              value: _getTotalPapers().toString(),
                            ),
                            const SizedBox(height: 10),
                            ResultRow(
                              label: 'Base Salary',
                              value: '₹${_baseSalary.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 10),
                            ResultRow(
                              label: 'Incentive Amount',
                              value: '₹${_incentiveAmount.toStringAsFixed(2)}',
                            ),
                            const Divider(height: 30),
                            ResultRow(
                              label: 'Net Amount',
                              value: '₹${_totalSalary.toStringAsFixed(2)}',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 6. SAVE & DOWNLOAD BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          minimumSize: const Size.fromHeight(60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _saveCalculation,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'Download PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          minimumSize: const Size.fromHeight(60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _downloadPDF,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addStaffDetails() async {
    if (_selectedDate == null || _staffCountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select date and enter staff count')),
      );
      return;
    }

    final staffCount = int.tryParse(_staffCountController.text);
    if (staffCount == null || staffCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid staff count')),
      );
      return;
    }

    final papersEvaluated = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffDetailsPage(staffCount: staffCount),
      ),
    );

    if (papersEvaluated != null) {
      setState(() {
        _evaluationDays.add(EvaluationDay(
          date: _selectedDate!,
          staffCount: staffCount,
          papersEvaluated: papersEvaluated,
        ));
      });
    }
  }

  void _removeDay(EvaluationDay day) {
    setState(() {
      _evaluationDays.remove(day);
    });
  }

  int _getTotalPapers() {
    return _evaluationDays.fold(0, (sum, day) => sum + day.papersEvaluated);
  }

  void _calculateSalary() async {
    if (_evaluationDays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add evaluation days first')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final ratePerPaper = prefs.getDouble('evaluation_rate') ?? 20.0;

    setState(() {
      final totalPapers = _getTotalPapers();
      _baseSalary = _evaluationDays.fold(0.0, (sum, day) {
        final papersPerStaff = day.papersEvaluated / day.staffCount;
        return sum + (papersPerStaff * ratePerPaper); // Use configured rate
      });
      _incentiveAmount = (totalPapers *
          0.1 *
          ratePerPaper); // Use configured rate for incentive too
      _totalSalary = _baseSalary + _incentiveAmount;
    });
  }

  void _refresh() {
    setState(() {
      _evaluationDays.clear();
      _staffCountController.clear();
      _selectedDate = null;
      _totalSalary = 0;
      _baseSalary = 0;
      _incentiveAmount = 0;
    });
  }

  Future<void> _saveCalculation() async {
    try {
      if (_totalSalary == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please calculate salary first')),
        );
        return;
      }

      await widget.dbHelper.insertEvaluation({
        'examiner_id': widget.examiner['id'],
        'date': DateTime.now().toIso8601String(),
        'total_staff': _evaluationDays.fold<int>(0, (sum, day) => sum + day.staffCount),
        'papers_evaluated': _getTotalPapers(),
        'base_salary': _baseSalary,
        'incentive_amount': _incentiveAmount,
        'total_salary': _totalSalary,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculation saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving calculation: $e')),
      );
    }
  }

  Future<void> _downloadPDF() async {
    if (_totalSalary == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please calculate salary first')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header Section
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'GURU NANAK COLLEGE (AUTONOMOUS)',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
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
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'CHIEF EXAMINER SALARY REPORT',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Chief Examiner Details Section
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CHIEF EXAMINER DETAILS',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 100, child: pw.Text('Name')),
                        pw.Text(': ${widget.examiner['fullname']}'),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 100, child: pw.Text('ID')),
                        pw.Text(': ${widget.examiner['examinerid']}'),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 100, child: pw.Text('Department')),
                        pw.Text(': ${widget.examiner['department']}'),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 100, child: pw.Text('Staff Count')),
                        pw.Text(
                            ': ${_evaluationDays.fold<int>(0, (sum, day) => sum + day.staffCount)}'),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 100, child: pw.Text('Date')),
                        pw.Text(
                            ': ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Evaluation Summary Section
            pw.Text(
              'EVALUATION SUMMARY',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Date'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Number of Examiners'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Papers Evaluated'),
                    ),
                  ],
                ),
                ..._evaluationDays.map(
                  (day) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          DateFormat('dd/MM/yyyy').format(day.date),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(day.staffCount.toString()),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(day.papersEvaluated.toString()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Calculation Results Section
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CALCULATION RESULTS',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Papers Evaluated'),
                        pw.Text('${_getTotalPapers()}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Base Salary'),
                        pw.Text('Rs.${_baseSalary.toStringAsFixed(2)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Incentive Amount'),
                        pw.Text('Rs.${_incentiveAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Net Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Rs.${_totalSalary.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final customLocation = prefs.getString('pdf_save_location');
    final String savePath;

    if (customLocation != null) {
      savePath = customLocation;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      savePath = directory.path;
    }

    final file = File(
      await _getUniqueFileName(savePath, widget.examiner['fullname']),
    );

    await file.writeAsBytes(await pdf.save());

    await widget.dbHelper.insertPdfHistory({
      'examiner_id': widget.examiner['id'],
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
  }

  Future<String> _getUniqueFileName(
      String basePath, String examinerName) async {
    String fileName = '$basePath/${examinerName}_Salary_Report.pdf';
    int counter = 1;

    while (await File(fileName).exists()) {
      fileName = '$basePath/${examinerName}_Salary_Report_$counter.pdf';
      counter++;
    }

    return fileName;
  }

  void _editDay(EvaluationDay day) async {
    _selectedDate = day.date;
    _staffCountController.text = day.staffCount.toString();

    final papersEvaluated = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffDetailsPage(
          staffCount: day.staffCount,
          initialPapers: day.papersEvaluated,
        ),
      ),
    );

    if (papersEvaluated != null) {
      setState(() {
        _evaluationDays.remove(day);
        _evaluationDays.add(EvaluationDay(
          date: _selectedDate!,
          staffCount: day.staffCount,
          papersEvaluated: papersEvaluated,
        ));
      });
    }
  }
}

class ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const ResultRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 18,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 18,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? const Color(0xFF6200EE) : null,
          ),
        ),
      ],
    );
  }
}
