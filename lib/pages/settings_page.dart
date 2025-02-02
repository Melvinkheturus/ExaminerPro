import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final DatabaseHelper dbHelper;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.dbHelper,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;
  String? _pdfSaveLocation;
  double _evaluationRate = 20.0; // Default rate
  final _rateController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadSettings();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pdfSaveLocation = prefs.getString('pdf_save_location');
      _evaluationRate = prefs.getDouble('evaluation_rate') ?? 20.0;
      _rateController.text = _evaluationRate.toString();
    });
  }

  Future<void> _updateEvaluationRate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Evaluation Rate'),
        content: Text(
          'Are you sure you want to update the evaluation rate to Rs.${_rateController.text}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Update',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final rate = double.tryParse(_rateController.text);
      if (rate != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('evaluation_rate', rate);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation rate updated successfully')),
        );
      }
    }
  }

  Future<void> _backupDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'chief_examiner.db');
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        final backupPath =
            p.join(result, 'chief_examiner_backup_$timestamp.db');
        await File(sourcePath).copy(backupPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database backed up to: $backupPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null) {
        // Show loading indicator
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await widget.dbHelper.restoreDatabase(result.files.single.path!);

        // Close loading indicator
        if (!mounted) return;
        Navigator.pop(context);

        // Show success message and restart app
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Database Restored'),
            content: const Text(
              'Database has been restored successfully. The application needs to restart to apply changes.',
            ),
            actions: [
              ElevatedButton(
                child: const Text('Restart Now'),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Phoenix.rebirth(
                      context); // You'll need to add the phoenix package
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all examiners, calculations, and PDF history. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear All Data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await widget.dbHelper.clearAllData();

        // Close loading indicator
        if (!mounted) return;
        Navigator.pop(context);

        // Show success message and restart app
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Data Cleared'),
            content: const Text(
              'All data has been cleared successfully. The application needs to restart to apply changes.',
            ),
            actions: [
              ElevatedButton(
                child: const Text('Restart Now'),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Phoenix.rebirth(context);
                },
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear data: $e')),
        );
      }
    }
  }

  Future<void> _updatePdfSaveLocation() async {
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update PDF Save Location'),
          content: Text(
            'Set PDF save location to:\n$selectedDirectory',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pdf_save_location', selectedDirectory);
        setState(() {
          _pdfSaveLocation = selectedDirectory;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PDF save location updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 8.0,
        radius: const Radius.circular(4.0),
        child: ListView(
          controller: _scrollController,
          children: [
            // General Settings Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'General Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              secondary: Icon(
                _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: _isDarkMode ? Colors.white : Colors.amber,
              ),
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme for the app'),
              value: _isDarkMode,
              activeColor: AppColors.primary,
              onChanged: (bool value) {
                setState(() {
                  _isDarkMode = value;
                });
                widget.onThemeChanged(value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('PDF Save Location'),
              subtitle: Text(_pdfSaveLocation ?? 'Default Location'),
              onTap: _updatePdfSaveLocation,
            ),
            const Divider(),

            // Evaluation Rate Configuration Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.currency_rupee),
                  SizedBox(width: 8),
                  Text(
                    'Evaluation Rate Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Rate: ₹${_evaluationRate.toStringAsFixed(2)} per paper',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rateController,
                              decoration: const InputDecoration(
                                labelText: 'New Rate (₹)',
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: AppColors.primary, width: 2),
                                ),
                                labelStyle: TextStyle(color: AppColors.primary),
                              ),
                              cursorColor: AppColors.primary,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _updateEvaluationRate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),

            // Data Management Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Data Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup Data'),
              subtitle: const Text('Export database to a file'),
              onTap: _backupDatabase,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore Data'),
              subtitle: const Text('Import data from backup'),
              onTap: _restoreDatabase,
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear All Data'),
              subtitle: const Text('Delete all data'),
              onTap: _clearAllData,
            ),
            const Divider(),

            // About Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('App Version'),
              subtitle: Text('Version 1.0.0'),
            ),
            const ListTile(
              leading: Icon(Icons.email),
              title: Text('Contact'),
              subtitle: Text('sankarmanikandan71@gmail.com'),
            ),
          ],
        ),
      ),
    );
  }
}
