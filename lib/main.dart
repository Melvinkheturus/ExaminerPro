import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/calculation_page.dart';
import 'pages/calculation_history_page.dart';
import 'pages/pdf_history_page.dart';
import 'helpers/database_helper.dart';
import 'constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for Windows
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final dbHelper = DatabaseHelper();
  await dbHelper.database; // Initialize the database

  // Set minimum window size
  if (Platform.isWindows) {
    setWindowTitle('ExaminerPro - Guru Nanak College');
    setWindowMinSize(const Size(1024, 768));
    setWindowMaxSize(Size.infinite);
  }

  runApp(const ExaminerProApp());
}

class ExaminerProApp extends StatefulWidget {
  const ExaminerProApp({super.key});

  @override
  _ExaminerProAppState createState() => _ExaminerProAppState();
}

class _ExaminerProAppState extends State<ExaminerProApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void updateThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDarkMode);
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ExaminerPro',
      theme: ThemeData(
        // Light Theme
        primaryColor: const Color.fromARGB(255, 98, 0, 238),
        scaffoldBackgroundColor: Colors.white,
        brightness: Brightness.light,

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryColor,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Text Theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.black87),
          displayMedium: TextStyle(color: Colors.black87),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
        ),

        // Card Theme
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        // Dark Theme
        primaryColor: AppColors.primaryColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,

        // AppBar Theme
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),

        // Text Theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white60),
        ),

        // Card Theme
        cardTheme: CardTheme(
          color: Colors.grey[850],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.white54),
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: ChiefExaminerPage(
        onThemeChanged: updateThemeMode,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

class ChiefExaminerPage extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  final bool isDarkMode;

  const ChiefExaminerPage({
    super.key,
    this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  ChiefExaminerPageState createState() => ChiefExaminerPageState();
}

class ChiefExaminerPageState extends State<ChiefExaminerPage>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _examiners = [];
  List<Map<String, dynamic>> _filteredExaminers = [];
  late BuildContext _context;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortOption = 'Name';
  final bool _isSidebarCollapsed = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadExaminers();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (_isSidebarCollapsed) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExaminers() async {
    final examiners = await _dbHelper.getExaminers();
    setState(() {
      _examiners = examiners;
      _filteredExaminers = List.from(examiners);
      _sortExaminers(); // Initial sort
    });
  }

  Future<void> _deleteExaminer(int id) async {
    await _dbHelper.deleteExaminer(id);
    _loadExaminers();
  }

  void _addExaminer() {
    Navigator.push(
      _context,
      MaterialPageRoute(builder: (ctx) => ProfilePage(dbHelper: _dbHelper)),
    ).then((_) => _loadExaminers());
  }

  void _filterAndSortExaminers(String query) {
    setState(() {
      _filteredExaminers = _examiners.where((examiner) {
        final name = examiner['fullname'].toString().toLowerCase();
        final id = examiner['examinerid'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) ||
            id.contains(query.toLowerCase());
      }).toList();

      _sortExaminers();
    });
  }

  void _sortExaminers() {
    setState(() {
      switch (_selectedSortOption) {
        case 'Name':
          _filteredExaminers.sort((a, b) =>
              (a['fullname'] as String).compareTo(b['fullname'] as String));
          break;
        case 'ID':
          _filteredExaminers.sort((a, b) =>
              (a['examinerid'] as String).compareTo(b['examinerid'] as String));
          break;
        // Add more sorting options if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _context = context;
    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            width: 250,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : const Color(0xFFF0F0F0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(1, 0),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Application Title
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'ExaminerPro',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF2D2D2D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1),
                ),
                // Navigation items with updated styling
                _buildNavItem(Icons.dashboard, "Dashboard", 0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1),
                ),
                _buildNavItem(Icons.history, "Calculation History", 1),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1),
                ),
                _buildNavItem(Icons.picture_as_pdf, "PDF History", 2),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1),
                ),
                _buildNavItem(Icons.settings, "Settings", -1, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => SettingsPage(
                        isDarkMode: widget.isDarkMode,
                        onThemeChanged: widget.onThemeChanged!,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Top Header
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: Row(
                      children: [
                        // Logo first
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/gnc_logo.png',
                            height: 80,
                            width: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.school, size: 60);
                            },
                          ),
                        ),
                        const SizedBox(
                            width: 16), // Add spacing between logo and text
                        // College details next
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'GURU NANAK COLLEGE (AUTONOMOUS)',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF2D2D2D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Affiliated to University of Madras | Accredited \'A++\' Grade by NAAC',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'CONTROLLER OF EXAMINATIONS',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF2D2D2D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDashboardTab(),
                        CalculationHistoryPage(
                          dbHelper: _dbHelper,
                          examinerId: -1,
                        ),
                        const PDFHistoryPage(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _addExaminer,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index,
      {VoidCallback? onTap}) {
    final isSelected = index >= 0 && _tabController.index == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: label,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? AppColors.primaryColor
              : (isDark ? Colors.white70 : Colors.black54),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: isSelected
                ? AppColors.primaryColor
                : (isDark ? Colors.white : const Color(0xFF2D2D2D)),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: isDark ? Colors.black26 : const Color(0xFFE8E8E8),
        onTap: onTap ??
            () {
              setState(() {
                _tabController.index = index;
              });
            },
      ),
    );
  }

  Widget _buildDashboardTab() {
    return Column(
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
                  decoration: const InputDecoration(
                    labelText: 'Search examiners...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _filterAndSortExaminers,
                ),
              ),
              const SizedBox(width: 8),

              // Sort Icon with Dropdown Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort, size: 28),
                onSelected: (String newValue) {
                  setState(() {
                    _selectedSortOption = newValue;
                    _sortExaminers();
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'Name',
                    child: Text('Sort by Name'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'ID',
                    child: Text('Sort by ID'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredExaminers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No examiners found'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addExaminer,
                        child: const Text('Add Examiner'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredExaminers.length,
                  itemBuilder: (ctx, index) {
                    final examiner = _filteredExaminers[index];
                    return Card(
                      elevation: 4,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (ctx) => CalculationPage(
                                examiner: examiner,
                                dbHelper: _dbHelper,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: examiner['image_path'] != null
                                  ? FileImage(File(examiner['image_path']))
                                  : null,
                              child: examiner['image_path'] == null
                                  ? Text(
                                      examiner['fullname'][0].toUpperCase(),
                                      style: const TextStyle(fontSize: 32),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              examiner['fullname'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'ID: ${examiner['examinerid']}',
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (ctx) => ProfilePage(
                                          dbHelper: _dbHelper,
                                          examiner: examiner,
                                        ),
                                      ),
                                    ).then((_) => _loadExaminers());
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _showDeleteDialog(examiner),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> examiner) async {
    return showDialog(
      context: _context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Examiner'),
        content: const Text('Are you sure you want to delete this examiner?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExaminer(examiner['id']);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Other updated classes omitted for brevity
