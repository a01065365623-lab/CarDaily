import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/anniversary.dart';
import '../models/drive.dart';
import '../models/plan.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cardaily.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createFreshSchema(db);
      },
    );
  }

  Future<void> _createFreshSchema(Database db) async {
    await db.execute('''
      CREATE TABLE drives (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        start_place TEXT,
        end_place TEXT,
        distance_km REAL,
        companion_tags TEXT NOT NULL,
        purpose_tag TEXT NOT NULL,
        mood_tag TEXT NOT NULL,
        mood_detail TEXT,
        memo TEXT,
        photo_paths TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_drives_date ON drives (date)');

    await db.execute('''
      CREATE TABLE plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        companionTag TEXT,
        memo TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_plans_date ON plans (date)');

    await db.execute('''
      CREATE TABLE anniversaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        memo TEXT,
        emoji TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_anniversaries_date ON anniversaries (date)');
  }

  // ---- drives ----

  Future<int> insertDrive(Drive drive) async {
    final db = await database;
    return db.insert('drives', drive.toMap()..remove('id'));
  }

  Future<List<Drive>> getDrivesForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'drives',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'createdAt ASC',
    );
    return rows.map(Drive.fromMap).toList();
  }

  Future<List<Drive>> getDrivesForRange(String fromDate, String toDate) async {
    final db = await database;
    final rows = await db.query(
      'drives',
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
      orderBy: 'date ASC, createdAt ASC',
    );
    return rows.map(Drive.fromMap).toList();
  }

  /// 캘린더에 점을 표시하기 위해, 구간 내 기록이 있는 날짜 집합만 가볍게 가져온다.
  Future<Set<String>> getLoggedDatesForRange(String fromDate, String toDate) async {
    final db = await database;
    final rows = await db.query(
      'drives',
      distinct: true,
      columns: ['date'],
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
    );
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<void> deleteDrive(int id) async {
    final db = await database;
    await db.delete('drives', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDrivesForDate(String date) async {
    final db = await database;
    await db.delete('drives', where: 'date = ?', whereArgs: [date]);
  }

  // ---- plans (정비 예약) ----

  Future<int> insertPlan(Plan plan) async {
    final db = await database;
    return db.insert('plans', plan.toMap()..remove('id'));
  }

  Future<Plan?> getPlanForDate(String date) async {
    final db = await database;
    final rows = await db.query('plans', where: 'date = ?', whereArgs: [date], limit: 1);
    if (rows.isEmpty) return null;
    return Plan.fromMap(rows.first);
  }

  Future<Set<String>> getPlannedDatesForRange(String fromDate, String toDate) async {
    final db = await database;
    final rows = await db.query(
      'plans',
      distinct: true,
      columns: ['date'],
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
    );
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<void> deletePlan(int id) async {
    final db = await database;
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  // ---- anniversaries (기념일/마일스톤) ----

  Future<int> insertAnniversary(Anniversary anniversary) async {
    final db = await database;
    return db.insert('anniversaries', anniversary.toMap()..remove('id'));
  }

  Future<List<Anniversary>> getAllAnniversaries() async {
    final db = await database;
    final rows = await db.query('anniversaries', orderBy: 'date ASC');
    return rows.map(Anniversary.fromMap).toList();
  }

  /// [monthDay]는 "MM-DD" 형식. 같은 날짜에 여러 기념일이 있으면 첫 번째만 반환한다.
  Future<Anniversary?> getAnniversaryForMonthDay(String monthDay) async {
    final db = await database;
    final rows = await db.query('anniversaries', where: 'date = ?', whereArgs: [monthDay], limit: 1);
    if (rows.isEmpty) return null;
    return Anniversary.fromMap(rows.first);
  }

  Future<void> deleteAnniversary(int id) async {
    final db = await database;
    await db.delete('anniversaries', where: 'id = ?', whereArgs: [id]);
  }
}
