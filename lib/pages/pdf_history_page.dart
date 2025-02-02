import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_colors.dart';
import 'package:path/path.dart' as p;

class PDFHistoryPage extends StatefulWidget {
  const PDFHistoryPage({super.key});

  @override
  State<PDFHistoryPage> createState() => _PDFHistoryPageState();
}

class _PDFHistoryPageState extends State<PDFHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  final Set<int> _selectedItems = {};
  bool _isSelectMode = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortOption = 'Date'; // Default sort option
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
        final name = record['fullname'].toString().toLowerCase();
        final id = record['examinerid'].toString().toLowerCase();
        final fileName = record['file_path'].split('/').last.toLowerCase();
        final searchQuery = query.toLowerCase();
        return name.contains(searchQuery) ||
            id.contains(searchQuery) ||
            fileName.contains(searchQuery);
      }).toList();

      _sortHistory(); // Apply sorting after filtering
    });
  }

  void _sortHistory() {
    setState(() {
      switch (_selectedSortOption) {
        case 'Date':
          _filteredHistory.sort((a, b) => DateTime.parse(b['created_at'])
              .compareTo(DateTime.parse(a['created_at'])));
          break;
        case 'Name':
          _filteredHistory.sort((a, b) =>
              (a['fullname'] as String).compareTo(b['fullname'] as String));
          break;
        case 'File Name':
          _filteredHistory.sort((a, b) {
            final aName = a['file_path'].split('/').last;
            final bName = b['file_path'].split('/').last;
            return aName.compareTo(bName);
          });
          break;
      }
    });
  }

  Future<void> _loadHistory() async {
    final history = await _dbHelper.getPdfHistoryWithExaminers();
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
        title: const Text('Delete All PDF History'),
        content: const Text(
            'Are you sure you want to delete all PDF history? This cannot be undone.'),
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
      await _dbHelper.clearPdfHistory();
      if (!mounted) return;
      await _loadHistory();
    }
  }

  Future<void> _deletePdf(int id, String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF'),
        content: const Text('Are you sure you want to delete this PDF?'),
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
      await _dbHelper.deletePdfHistory(id);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _loadHistory();
    }
  }

  Future<void> _showInExplorer(String filePath) async {
    if (Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      final customLocation = prefs.getString('pdf_save_location');

      // Use the custom location if set, otherwise extract from file path
      final directory =
          customLocation ?? filePath.substring(0, filePath.lastIndexOf('\\'));

      Process.run('explorer.exe', [directory]);
    }
  }

  Future<void> _openPdf(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await OpenFile.open(filePath);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file not found')),
        );
      }
    }
  }

  Future<void> _downloadSelected([List<int>? specificIds]) async {
    try {
      final ids = specificIds ?? _selectedItems.toList();
      if (ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items selected')),
        );
        return;
      }

      // Get save location
      final prefs = await SharedPreferences.getInstance();
      String? customLocation = prefs.getString('pdf_save_location');

      // Get selected PDFs
      final selectedPdfs =
          _history.where((pdf) => ids.contains(pdf['id'])).toList();

      for (var pdf in selectedPdfs) {
        final sourceFile = File(pdf['file_path']);
        if (await sourceFile.exists()) {
          final fileName = pdf['file_path'].split('/').last;

          String destinationPath;
          if (customLocation != null && customLocation.isNotEmpty) {
            // Normalize Windows path
            customLocation = customLocation.replaceAll('\\', '/');
            final saveDir = Directory(customLocation);
            if (!await saveDir.exists()) {
              await saveDir.create(recursive: true);
            }
            destinationPath = p.join(customLocation, fileName);
            if (Platform.isWindows) {
              destinationPath = destinationPath.replaceAll('/', '\\');
            }
          } else {
            final output = await getApplicationDocumentsDirectory();
            final saveDir = Directory('${output.path}/Chief Examiner PDFs');
            if (!await saveDir.exists()) {
              await saveDir.create(recursive: true);
            }
            destinationPath = p.join(saveDir.path, fileName);
          }

          // Copy file to destination
          await sourceFile.copy(destinationPath);

          // Open the file after download
          await OpenFile.open(destinationPath);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Files downloaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading files: $e')),
      );
    }
  }

  Future<void> _downloadAll() async {
    if (_filteredHistory.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files to download')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final baseDir = Directory('${directory.path}/Chief Examiner');

      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      // Group all files by examiner
      final groupedFiles = <String, List<Map<String, dynamic>>>{};
      for (var item in _filteredHistory) {
        final examinerName = item['fullname'] ?? 'Unknown';
        groupedFiles.putIfAbsent(examinerName, () => []).add(item);
      }

      // Copy files to respective examiner folders
      for (var entry in groupedFiles.entries) {
        final examinerDir = Directory('${baseDir.path}/${entry.key}');
        if (!await examinerDir.exists()) {
          await examinerDir.create();
        }

        for (var file in entry.value) {
          final sourceFile = File(file['file_path']);
          if (await sourceFile.exists()) {
            final fileName = sourceFile.path.split('/').last;
            final destFile = File('${examinerDir.path}/$fileName');
            await sourceFile.copy(destFile.path);
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All files downloaded to: ${baseDir.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error downloading files')),
      );
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupHistoryByExaminer() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    // First, add overall reports if they exist
    final overallReports = _filteredHistory
        .where((item) => item['is_overall_report'] == 1)
        .toList();
    if (overallReports.isNotEmpty) {
      grouped['Overall Reports'] = overallReports;
      _expandedGroups.putIfAbsent('Overall Reports', () => true);
    }

    // Then add the rest of the PDFs
    for (var item
        in _filteredHistory.where((item) => item['is_overall_report'] != 1)) {
      final examinerName = item['fullname'] ?? 'Unknown Examiner';
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
                      labelText: 'Search PDFs...',
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
                      value: 'Name',
                      child: Text('Sort by Name'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'File Name',
                      child: Text('Sort by File Name'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Download Options Section
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
                        : () => _downloadSelected(),
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

          // PDF List
          Expanded(
            child: _filteredHistory.isEmpty
                ? const Center(child: Text('No PDF history found'))
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
                            // Examiner Header with Select All option
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
                                            // Select all records for this examiner
                                            for (var record
                                                in examinerRecords) {
                                              _selectedItems.add(record['id']);
                                            }
                                          } else {
                                            // Deselect all records for this examiner
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
                                    '${examinerRecords.length} files',
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
                            // Records List
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
                                      DateFormat('dd/MM/yyyy HH:mm').format(
                                        DateTime.parse(record['created_at']),
                                      ),
                                    ),
                                    subtitle: Text(
                                      record['file_path'].split('/').last,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: _isSelectMode
                                        ? null
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility),
                                                color: Colors.blue,
                                                onPressed: () => _openPdf(
                                                    record['file_path']),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.folder_open),
                                                color: Colors.amber,
                                                onPressed: () =>
                                                    _showInExplorer(
                                                        record['file_path']),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                color: Colors.red,
                                                onPressed: () => _deletePdf(
                                                    record['id'],
                                                    record['file_path']),
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
