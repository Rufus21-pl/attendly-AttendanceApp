import 'dart:io';
import 'dart:convert';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/backup/backup_scheduler.dart';
import 'package:attendly/data/backup/database_backup_service.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/database/database_manager_interface.dart';
import 'package:attendly/data/database/sqlite_errors.dart';
import 'package:attendly/data/settings/settings_store.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:attendly/data/database/app_database.dart';


class DatabaseManager implements DatabaseManagerInterface {
  static const String _tag = "Database";

  /// Only tests pass a [backupService] or a [backupDelay].
  DatabaseManager({DatabaseBackupService? backupService, Duration? backupDelay})
      : _backupService = backupService ?? DatabaseBackupService(),
        _backupDelay = backupDelay ?? BackupScheduler.defaultDelay;

  final DatabaseBackupService _backupService;
  final Duration _backupDelay;

  AppDatabase? _db;
  File? _oldDbFile;
  File? _currentDbFile;

  /// Writes the backup of [_db] after changes. Exists while [_db] is open.
  BackupScheduler? _backupScheduler;

  bool _isDamaged = false;

  @override
  bool get isOpenDatabaseDamaged => _isDamaged;

  @override
  String? get currentDbPath => _currentDbFile?.path;

  @override
  int? get dbYear {
    final path = currentDbPath;
    if (path == null) return null;

    final match = RegExp(r'db_(\d{4})').firstMatch(path);
    final yearStr = match?.group(1);

    return yearStr != null ? int.tryParse(yearStr) : null;
  }

  @override
  AppDatabase get databaseConnection {
    if (_db == null) {
      throw DatabaseFailedInit("Database not initialized!");
    }
    return _db!;
  }

  @override
  Future<bool> checkForYearRollover() async {
    final data = await _loadSettings();
    _currentDbFile = File(data['file_path']);
    final yearFromFile = int.tryParse(data['current_year'].toString()) ?? getCurrentYearAsInt();

    final currentYear = getCurrentYearAsInt();
    final dbExists = await _currentDbFile!.exists();
    AppLogger.i(_tag, "Year check: settings year=$yearFromFile, system year=$currentYear, "
        "configured db=${_currentDbFile!.path} (exists: $dbExists)");

    // A rollover only makes sense if there is an old database to carry people over from.
    if (yearFromFile < currentYear && dbExists) {
      _oldDbFile = _currentDbFile;
      AppLogger.i(_tag, "Year rollover needed: $yearFromFile -> $currentYear");
      return true;
    }
    if (yearFromFile < currentYear) {
      AppLogger.w(_tag, "Year changed but the old database is missing, no rollover possible");
    }

    return false;
  }

  @override
  Future<bool> needsInitialSetup() async {
    if (_currentDbFile == null) {
      final data = await _loadSettings();
      _currentDbFile = File(data['file_path']);
    }
    if (await _currentDbFile!.exists()) return false;

    final dbFiles = await StorageManager.listDbFiles();
    if (dbFiles.isEmpty) {
      AppLogger.i(_tag, "No database files found, initial setup needed");
      return true;
    }
    AppLogger.w(_tag, "Configured db ${_currentDbFile!.path} is missing, but other databases exist: "
        "${dbFiles.map((f) => p.basename(f.path)).join(', ')}");
    return false;
  }

  @override
  Future<void> openDatabase({File? file, Future<void> Function()? onMigrationStarted}) async {
    if (file == null && _currentDbFile == null) {
      final data = await _loadSettings();
      _currentDbFile = File(data['file_path']);
    }

    File targetFile = file ?? _currentDbFile!;

    if (!await targetFile.exists()) {
      AppLogger.e(_tag, "Cannot open ${targetFile.path}: file does not exist");
      throw DatabaseFileMissingException(targetFile.path);
    }

    final sizeBytes = await targetFile.length();
    AppLogger.i(_tag, "Opening ${targetFile.path} ($sizeBytes bytes"
        "${file != null ? ', selected by user' : ''})");

    await closeDatabase();
    _currentDbFile = targetFile;

    // SQLite takes an empty file for a new database and creates the tables
    // in it. The empty database would then replace the backup with the data.
    if (sizeBytes == 0) {
      AppLogger.e(_tag, "Cannot open ${targetFile.path}: the file is empty");
      throw DatabaseCorruptedException(targetFile.path);
    }

    _db = AppDatabase(AppDatabase.openConnection(targetFile), onMigrationStarted: onMigrationStarted);

    final stopwatch = Stopwatch()..start();
    try {
      await _db!.forceOpen();
    } catch (e, stackTrace) {
      AppLogger.e(_tag, "Opening ${targetFile.path} failed after ${stopwatch.elapsedMilliseconds} ms", e, stackTrace);
      if (isCorruptionError(e)) {
        await _closeDamaged();
        throw DatabaseCorruptedException(targetFile.path);
      }
      rethrow;
    }

    AppLogger.i(_tag, "Opened ${p.basename(targetFile.path)} in ${stopwatch.elapsedMilliseconds} ms");

    // The first query can pass on a file that is damaged further inside.
    _isDamaged = !await _backupService.isHealthy(_db!);
    if (_isDamaged) {
      AppLogger.e(_tag, "${p.basename(targetFile.path)} opened, but the check found damage");
    }
    await _startBackups();
  }

  @override
  Future<void> createDatabase() async {
    final dir = await StorageManager.getExternalDocumentsDir();
    if (dir == null) {
      AppLogger.e(_tag, "Cannot create database: storage directory not accessible");
      throw Exception("Could not access external storage");
    }

    String newYear = yearToString(getCurrentYear());
    String newDbPath = p.join(dir.path, "db_$newYear.db");
    File newDbFile = File(newDbPath);
    AppLogger.i(_tag, await newDbFile.exists()
        ? "Create requested, but $newDbPath already exists - opening it instead"
        : "Creating new database $newDbPath");

    await closeDatabase();

    try {
      _db = AppDatabase(AppDatabase.openConnection(newDbFile));
      await _db!.forceOpen();
    } catch (e, stackTrace) {
      AppLogger.e(_tag, "Creating/opening $newDbPath failed", e, stackTrace);
      rethrow;
    }

    await SettingsStore.update({'current_year': newYear, 'file_path': newDbPath});
    _currentDbFile = newDbFile;
    AppLogger.i(_tag, "Database $newDbPath ready and set as default");
    await _startBackups();
  }

  @override
  Future<void> performYearRolloverAndOpen({Future<void> Function()? onMigrationStarted}) async {

    if (_oldDbFile == null) {
      AppLogger.w(_tag, "Rollover requested but no old database is known, creating an empty one");
      await createDatabase();
      return;
    }

    final oldPath = _oldDbFile!.path;
    AppLogger.i(_tag, "Year rollover started from $oldPath");

    try {
      AppLogger.i(_tag, "Rollover step 1/3: migrating old database schema");
      final tempOldDb = AppDatabase(AppDatabase.openConnection(_oldDbFile!), onMigrationStarted: onMigrationStarted);
      await tempOldDb.forceOpen();
      await tempOldDb.close();

      AppLogger.i(_tag, "Rollover step 2/3: creating database for the new year");
      await createDatabase();

      AppLogger.i(_tag, "Rollover step 3/3: copying people directory");
      await _db!.copyPersonDirFromOldDatabase(oldPath);
      // The copy is one plain SQL statement, which does not report a write.
      _backupScheduler?.requestBackup();
    } catch (e, stackTrace) {
      AppLogger.e(_tag, "Year rollover from $oldPath failed", e, stackTrace);
      rethrow;
    }
    AppLogger.i(_tag, "Year rollover finished, now using $currentDbPath");
  }

  @override
  Future<void> closeDatabase() async {
    if (_db != null) {
      AppLogger.i(_tag, "Closing ${_currentDbFile != null ? p.basename(_currentDbFile!.path) : 'database'}");
      // A change of the last seconds must be in the backup before the file closes.
      await _backupScheduler?.close();
      _backupScheduler = null;
      _isDamaged = false;
      try {
        await _db!.close();
      } catch (e, stackTrace) {
        AppLogger.e(_tag, "Closing the database failed", e, stackTrace);
        rethrow;
      }
      _db = null;
    }
  }

  @override
  Future<String> getSettingsJsonContent() async {
    try {
      final json = await SettingsStore.load();
      if (json == null) return '{}';
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (e, stackTrace) {
      AppLogger.e(_tag, "Reading settings.json for the debug view failed", e, stackTrace);
      return '{ "error": "${e.toString()}" }';
    }
  }

  // =======================================================================
  // BACKUP
  // =======================================================================

  @override
  Future<void> flushBackup() async {
    await _backupScheduler?.flush();
  }

  @override
  Future<void> backupNow() async {
    final scheduler = _backupScheduler;
    if (scheduler == null) return;
    scheduler.requestBackup();
    await scheduler.flush();
  }

  @override
  Future<List<BackupInfo>> listBackups() => _backupService.listBackups();

  @override
  Future<void> restoreBackup(BackupInfo backup) async {
    AppLogger.i(_tag, "Restoring ${backup.dbFileName} from its backup");
    await closeDatabase();

    final restored = await _backupService.restore(backup);

    // The restored file is the main database again.
    final year = backup.dbYear;
    await SettingsStore.update({
      'file_path': restored.path,
      if (year != null) 'current_year': '$year',
    });
    _currentDbFile = restored;
    _oldDbFile = null;
  }

  /// Starts the backups of the database that was just opened. The first
  /// backup runs soon after, when the file has none or changed since.
  Future<void> _startBackups() async {
    final db = _db!;
    final dbFile = _currentDbFile!;

    final scheduler = BackupScheduler(
      writes: db.tableUpdates(),
      backup: () => _backupService.backupNow(db, dbFile),
      delay: _backupDelay,
    )..start();
    _backupScheduler = scheduler;

    try {
      if (await _backupService.needsBackup(dbFile)) scheduler.requestBackup();
    } catch (e, stackTrace) {
      AppLogger.e(_tag, "Checking the backup of ${p.basename(dbFile.path)} failed", e, stackTrace);
    }
  }

  /// Closes a database file that SQLite cannot read, without a backup.
  Future<void> _closeDamaged() async {
    try {
      await _db?.close();
    } catch (e, stackTrace) {
      AppLogger.e(_tag, "Closing the damaged database failed", e, stackTrace);
    }
    _db = null;
  }

  // =======================================================================
  // PRIVATE JSON HELPERS
  // =======================================================================

  /// settings.json is created with defaults if it does not exist yet.
  Future<Map<String, dynamic>> _loadSettings() async {
    final data = await SettingsStore.load();
    if (data == null) {
      throw DatabaseFailedInit("Could not access the storage directory. Please check app permissions.");
    }
    return data;
  }
}
