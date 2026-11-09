import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/anniversary.dart';
import '../models/drive.dart';
import '../models/fuel_log.dart';
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
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createFreshSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 이 시점의 _createFuelLogsTable은 이미 최신(v4) 스키마로 테이블을 만들기
          // 때문에, 방금 새로 만든 테이블을 다시 마이그레이션할 필요가 없다.
          await _createFuelLogsTable(db);
        } else if (oldVersion < 4) {
          // v2~v3에서 만들어진 fuel_logs는 amount_liters(구) 스키마이므로 변환한다.
          await _migrateFuelLogsAmountAndType(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE plans ADD COLUMN type TEXT NOT NULL DEFAULT '기타'",
          );
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE drives ADD COLUMN song_title TEXT');
        }
        if (oldVersion < 6) {
          // 기존 기록은 그대로 두고 nullable 컬럼만 추가한다.
          await db.execute('ALTER TABLE drives ADD COLUMN places_note TEXT');
        }
      },
    );
  }

  /// fuel_logs: amount_liters(리터 전용) → amount(연료 종류 무관 공용 수치)로 바꾸고,
  /// 연료 종류를 구분하는 fuel_type 컬럼을 추가한다. 기존 행은 전부 리터 단위
  /// 주유였으므로 fuel_type을 '기름'으로 채운다.
  Future<void> _migrateFuelLogsAmountAndType(Database db) async {
    await db.execute('''
      CREATE TABLE fuel_logs_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        fuel_type TEXT NOT NULL,
        amount REAL,
        cost REAL NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO fuel_logs_new (id, date, fuel_type, amount, cost, memo, created_at)
      SELECT id, date, '기름', amount_liters, cost, memo, created_at FROM fuel_logs
    ''');
    await db.execute('DROP TABLE fuel_logs');
    await db.execute('ALTER TABLE fuel_logs_new RENAME TO fuel_logs');
    await db.execute('CREATE INDEX idx_fuel_logs_date ON fuel_logs (date)');
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
        song_title TEXT,
        places_note TEXT,
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
        createdAt TEXT NOT NULL,
        type TEXT NOT NULL
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
    await db.execute(
      'CREATE INDEX idx_anniversaries_date ON anniversaries (date)',
    );

    await _createFuelLogsTable(db);
  }

  /// "기름 먹은 날" 기록 테이블. drives와는 연결되지 않는 독립적인 주유/충전 기록이다.
  Future<void> _createFuelLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE fuel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        fuel_type TEXT NOT NULL,
        amount REAL,
        cost REAL NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_fuel_logs_date ON fuel_logs (date)');
  }

  // ---- drives ----

  Future<int> insertDrive(Drive drive) async {
    final db = await database;
    return db.insert('drives', drive.toMap()..remove('id'));
  }

  Future<void> updateDrive(Drive drive) async {
    final db = await database;
    await db.update(
      'drives',
      drive.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [drive.id],
    );
  }

  Future<List<Drive>> getDrivesForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'drives',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at ASC',
    );
    return rows.map(Drive.fromMap).toList();
  }

  Future<List<Drive>> getDrivesForRange(String fromDate, String toDate) async {
    final db = await database;
    final rows = await db.query(
      'drives',
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(Drive.fromMap).toList();
  }

  /// 캘린더에 점을 표시하기 위해, 구간 내 기록이 있는 날짜 집합만 가볍게 가져온다.
  Future<Set<String>> getLoggedDatesForRange(
    String fromDate,
    String toDate,
  ) async {
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

  // ---- plans (병원 예약) ----

  Future<int> insertPlan(Plan plan) async {
    final db = await database;
    return db.insert('plans', plan.toMap()..remove('id'));
  }

  Future<void> updatePlan(Plan plan) async {
    final db = await database;
    await db.update(
      'plans',
      plan.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<Plan?> getPlanForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'plans',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Plan.fromMap(rows.first);
  }

  /// 수정 후 최신 상태를 다시 불러올 때 쓴다.
  Future<Plan?> getPlanById(int id) async {
    final db = await database;
    final rows = await db.query(
      'plans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Plan.fromMap(rows.first);
  }

  /// 통계 화면에서 방문 횟수/최근 방문일/유형별 분포를 계산하기 위해 전체 예약을 가져온다.
  Future<List<Plan>> getAllPlans() async {
    final db = await database;
    final rows = await db.query('plans', orderBy: 'date DESC, createdAt DESC');
    return rows.map(Plan.fromMap).toList();
  }

  Future<Set<String>> getPlannedDatesForRange(
    String fromDate,
    String toDate,
  ) async {
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

  /// [monthDay]는 "MM-DD" 형식. 과거에 저장된 매년 반복 기념일 전용 조회다.
  /// 같은 날짜에 여러 기념일이 있으면 첫 번째만 반환한다.
  Future<Anniversary?> getAnniversaryForMonthDay(String monthDay) async {
    final db = await database;
    final rows = await db.query(
      'anniversaries',
      where: 'date = ?',
      whereArgs: [monthDay],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Anniversary.fromMap(rows.first);
  }

  /// [date]는 "yyyy-MM-dd" 형식. 특정 연도의 1회성 기념일 전용 조회다.
  /// 같은 날짜에 여러 기념일이 있으면 첫 번째만 반환한다.
  Future<Anniversary?> getAnniversaryForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'anniversaries',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Anniversary.fromMap(rows.first);
  }

  Future<void> deleteAnniversary(int id) async {
    final db = await database;
    await db.delete('anniversaries', where: 'id = ?', whereArgs: [id]);
  }

  // ---- fuel_logs (기름 먹은 날) ----

  Future<int> insertFuelLog(FuelLog fuelLog) async {
    final db = await database;
    return db.insert('fuel_logs', fuelLog.toMap()..remove('id'));
  }

  Future<void> updateFuelLog(FuelLog fuelLog) async {
    final db = await database;
    await db.update(
      'fuel_logs',
      fuelLog.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [fuelLog.id],
    );
  }

  Future<List<FuelLog>> getAllFuelLogs() async {
    final db = await database;
    final rows = await db.query(
      'fuel_logs',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(FuelLog.fromMap).toList();
  }

  /// 일자 상세 화면에서 그 날짜의 기름 먹은 날 기록으로 바로 이동할 때 쓴다.
  /// 같은 날짜에 여러 건이 있으면 가장 최근에 저장된 것을 반환한다.
  Future<FuelLog?> getFuelLogForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'fuel_logs',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FuelLog.fromMap(rows.first);
  }

  /// 캘린더에 독립 아이콘을 표시하기 위해, 구간 내 기록이 있는 날짜 집합만 가볍게 가져온다.
  Future<Set<String>> getFuelLogDatesForRange(
    String fromDate,
    String toDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'fuel_logs',
      distinct: true,
      columns: ['date'],
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
    );
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<void> deleteFuelLog(int id) async {
    final db = await database;
    await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
  }
}
