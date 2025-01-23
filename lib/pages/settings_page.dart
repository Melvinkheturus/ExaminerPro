import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;
  String? _pdfSaveLocation;
  double _evaluationRate = 20.0;  // Default rate
  final _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadSettings();
  }

  @override
  void dispose() {
    _rateController.dispose();
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

  Future<void> _changePdfLocation() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pdf_save_location', selectedDirectory);
      setState(() {
        _pdfSaveLocation = selectedDirectory;
      });
    }
  }

  Future<void> _updateEvaluationRate() async {
    final newRate = double.tryParse(_rateController.text);
    if (newRate != null && newRate > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('evaluation_rate', newRate);
      setState(() {
        _evaluationRate = newRate;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation rate updated successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid rate')),
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
      // Get the database directory
      final dbPath = await getDatabasesPath();
      final destinationPath = p.join(dbPath, 'chief_examiner.db');

      // Pick the backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null) {
        // Close the database before restoring
        await _closeDatabase();

        // Delete existing database if it exists
        final destinationFile = File(destinationPath);
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }

        // Copy the backup file
        final sourceFile = File(result.files.single.path!);
        await sourceFile.copy(destinationPath);

        // Reopen the database
        await _reopenDatabase();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  Future<void> _closeDatabase() async {
    final db = await openDatabase('chief_examiner.db');
    await db.close();
  }

  Future<void> _reopenDatabase() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
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
              color: _isDarkMode ? Colors.amber : Colors.blueGrey,
            ),
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme for the app'),
            value: _isDarkMode,
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
            onTap: _changePdfLocation,
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
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _updateEvaluationRate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 98, 0, 238),  // Fixed color for both themes
                            foregroundColor: Colors.white,  // Text color
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
    );
  }
}
