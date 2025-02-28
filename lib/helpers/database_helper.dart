import 'dart:async';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'chief_examiner.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE examiners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullname TEXT NOT NULL,
        examinerid TEXT NOT NULL UNIQUE,
        department TEXT NOT NULL,
        position TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE evaluations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        examiner_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        total_staff INTEGER NOT NULL,
        total_papers INTEGER NOT NULL,
        base_salary REAL NOT NULL,
        incentive_amount REAL NOT NULL,
        total_salary REAL NOT NULL,
        FOREIGN KEY (examiner_id) REFERENCES examiners (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pdf_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        examiner_id INTEGER,
        file_path TEXT,
        created_at TEXT,
        is_overall_report INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pdf_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          examiner_id INTEGER,
          file_path TEXT,
          created_at TEXT
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add is_overall_report column to pdf_history table
      await db.execute('''
        ALTER TABLE pdf_history 
        ADD COLUMN is_overall_report INTEGER DEFAULT 0
      ''');
    }
  }

  // Examiner operations
  Future<int> insertExaminer(Map<String, dynamic> examiner) async {
    final db = await database;
    return await db.insert('examiners', examiner);
  }

  Future<List<Map<String, dynamic>>> getExaminers() async {
    final db = await database;
    return await db.query('examiners', orderBy: 'fullname');
  }

  Future<Map<String, dynamic>?> getExaminer(int id) async {
    final db = await database;
    final results = await db.query(
      'examiners',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateExaminer(int id, Map<String, dynamic> examiner) async {
    final db = await database;
    return await db.update(
      'examiners',
      examiner,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExaminer(int id) async {
    final db = await database;
    return await db.delete(
      'examiners',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Evaluation operations
  Future<int> insertEvaluation(Map<String, dynamic> evaluation) async {
    final db = await database;
    return await db.insert('evaluations', evaluation);
  }

  Future<List<Map<String, dynamic>>> getEvaluations(int examinerId) async {
    final db = await database;
    return await db.query(
      'evaluations',
      where: 'examiner_id = ?',
      whereArgs: [examinerId],
      orderBy: 'date DESC',
    );
  }

  Future<int> deleteEvaluation(int id) async {
    final db = await database;
    return await db.delete(
      'evaluations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearCalculationHistory() async {
    final db = await database;
    await db.delete('evaluations');
  }

  Future<void> insertPdfHistory(Map<String, dynamic> history) async {
    final db = await database;
    await db.insert(
      'pdf_history',
      history,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPdfHistory() async {
    final db = await database;
    return await db.query('pdf_history', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getCalculationHistory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        e.*, 
        ex.fullname as examiner_name, 
        ex.examinerid, 
        ex.department,
        e.total_papers,
        e.total_staff,
        e.total_salary,
        e.base_salary,
        e.incentive_amount,
        e.date
      FROM evaluations e
      LEFT JOIN examiners ex ON e.examiner_id = ex.id
      ORDER BY e.date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getPdfHistoryWithExaminers() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.*, 
        CASE 
          WHEN p.is_overall_report = 1 THEN 'Overall Report'
          ELSE e.fullname 
        END as fullname,
        e.examinerid 
      FROM pdf_history p 
      LEFT JOIN examiners e ON p.examiner_id = e.id 
      ORDER BY p.is_overall_report DESC, p.created_at DESC
    ''');
  }

  Future<void> clearPdfHistory() async {
    final db = await database;
    await db.delete('pdf_history');
  }

  Future<void> deletePdfHistory(int id) async {
    final db = await database;
    await db.delete(
      'pdf_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getCalculationHistoryByExaminer(
      int examinerId) async {
    final db = await database;
    return await db.query(
      'evaluations',
      where: 'examiner_id = ?',
      whereArgs: [examinerId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPdfHistoryByExaminer(
      int examinerId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, e.fullname, e.examinerid 
      FROM pdf_history p 
      LEFT JOIN examiners e ON p.examiner_id = e.id 
      WHERE p.examiner_id = ?
      ORDER BY p.created_at DESC
    ''', [examinerId]);
  }

  Future<void> deleteCalculation(int id) async {
    final db = await database;
    await db.delete(
      'evaluations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'chief_examiner.db');
    await databaseFactory.deleteDatabase(path);
  }

  Future<void> clearAllData() async {
    final db = await database;
    try {
      // Start a transaction
      await db.transaction((txn) async {
        // Disable foreign key constraints temporarily
        await txn.execute('PRAGMA foreign_keys = OFF');

        // Clear all tables
        await txn.rawDelete('DELETE FROM evaluations');
        await txn.rawDelete('DELETE FROM pdf_history');
        await txn.rawDelete('DELETE FROM examiners');

        // Reset auto-increment counters
        await txn.execute('DELETE FROM sqlite_sequence');

        // Re-enable foreign key constraints
        await txn.execute('PRAGMA foreign_keys = ON');
      });

      // Vacuum the database
      await db.execute('VACUUM');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreDatabase(String backupPath) async {
    try {
      // Close existing connection first
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Get database paths
      final dbPath = await getDatabasesPath();
      final currentPath = p.join(dbPath, 'chief_examiner.db');

      // Create a temporary copy of the backup
      final tempPath = '${currentPath}_temp';
      await File(backupPath).copy(tempPath);

      // Test if the backup is valid by trying to open it
      final testDb = await openDatabase(tempPath);

      // Verify tables exist
      await testDb.query('examiners');
      await testDb.query('evaluations');
      await testDb.query('pdf_history');

      // Close test connection
      await testDb.close();

      // If we got here, the backup is valid. Replace the current database
      await File(tempPath).copy(currentPath);

      // Delete temp file
      await File(tempPath).delete();

      // Initialize new connection
      _database = null;
      _database = await openDatabase(
        currentPath,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      // If anything goes wrong, ensure we have a fresh database
      _database = null;
      await _initDatabase();
      rethrow;
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> initializeDatabase() async {
    _database = await _initDatabase();
  }
}
