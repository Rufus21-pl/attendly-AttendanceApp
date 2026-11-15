import 'dart:io';

import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/database/database_manager_interface.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_database.dart';

/// [DatabaseManagerInterface] backed by an in-memory database, without touching
/// storage, permissions or settings.json.
///
/// Every call is recorded in [calls], so tests can check the order in which
/// startup asks its questions.
class FakeDatabaseManager implements DatabaseManagerInterface {
  FakeDatabaseManager({
    this.rolloverNeeded = false,
    this.initialSetupNeeded = false,
    this.openError,
    this.defaultPath = '/storage/emulated/0/Documents/AttendlyDb/db_2026.db',
  });

  bool rolloverNeeded;
  bool initialSetupNeeded;

  /// Thrown by [openDatabase] while set.
  Object? openError;

  final String defaultPath;
  final List<String> calls = [];

  AppDatabase? _db;
  String? _currentPath;

  /// The database in settings.json. Known after the startup checks, also
  /// when it cannot be opened.
  String? _configuredPath;

  @override
  AppDatabase get databaseConnection {
    final db = _db;
    if (db == null) throw DatabaseFailedInit('Database not initialized!');
    return db;
  }

  @override
  String? get currentDbPath => _currentPath ?? _configuredPath;

  @override
  int? get dbYear {
    final match = RegExp(r'db_(\d{4})').firstMatch(_currentPath ?? '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  Future<bool> checkForYearRollover() async {
    calls.add('checkForYearRollover');
    _configuredPath ??= defaultPath;
    return rolloverNeeded;
  }

  @override
  Future<bool> needsInitialSetup() async {
    calls.add('needsInitialSetup');
    return initialSetupNeeded;
  }

  @override
  Future<void> openDatabase({File? file, Future<void> Function()? onMigrationStarted}) async {
    calls.add(file == null ? 'openDatabase' : 'openDatabase(${file.path})');
    if (openError != null) throw openError!;
    await closeDatabase();
    _db = createTestDatabase();
    _currentPath = file?.path ?? _configuredPath ?? defaultPath;
  }

  @override
  Future<void> createDatabase() async {
    calls.add('createDatabase');
    await closeDatabase();
    _db = createTestDatabase();
    _currentPath = defaultPath;
  }

  @override
  Future<void> performYearRolloverAndOpen({Future<void> Function()? onMigrationStarted}) async {
    calls.add('performYearRolloverAndOpen');
    await createDatabase();
  }

  @override
  Future<void> closeDatabase() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<String> getSettingsJsonContent() async => '{}';

  /// What [listBackups] returns.
  List<BackupInfo> backups = [];

  /// What [isOpenDatabaseDamaged] reports after a database was opened.
  bool damaged = false;

  /// How often [backupNow] was called.
  int manualBackups = 0;

  @override
  bool get isOpenDatabaseDamaged => _db != null && damaged;

  @override
  Future<void> backupNow() async => manualBackups++;

  /// How often [flushBackup] was called.
  int backupFlushes = 0;

  @override
  Future<void> flushBackup() async => backupFlushes++;

  @override
  Future<List<BackupInfo>> listBackups() async => backups;

  @override
  Future<void> restoreBackup(BackupInfo backup) async {
    calls.add('restoreBackup(${backup.dbFileName})');
    await closeDatabase();
    // The restored file is a good database and the main one again.
    openError = null;
    damaged = false;
    initialSetupNeeded = false;
    _configuredPath = p.posix.join(p.posix.dirname(defaultPath), backup.dbFileName);
  }
}
