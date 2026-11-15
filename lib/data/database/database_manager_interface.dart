import 'dart:io';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/app_database.dart';

abstract interface class DatabaseManagerInterface {
  AppDatabase get databaseConnection;

  String? get currentDbPath;

  int? get dbYear;

  Future<bool> checkForYearRollover();

  /// True on a fresh install: the configured database does not exist and
  /// there are no other database files in the storage directory either.
  Future<bool> needsInitialSetup();

  Future<void> openDatabase({File? file, Future<void> Function()? onMigrationStarted});

  Future<void> createDatabase();

  Future<void> performYearRolloverAndOpen({Future<void> Function()? onMigrationStarted});

  Future<void> closeDatabase();

  Future<String> getSettingsJsonContent();

  /// Writes a backup that is waiting for its delay now, e.g. before the app
  /// goes to the background. Does nothing when no backup is requested.
  Future<void> flushBackup();

  /// The backup copies of all databases, newest first.
  Future<List<BackupInfo>> listBackups();

  /// Closes the open database, puts [backup] back as its database file and
  /// makes that file the main database in settings.json. The caller opens it.
  Future<void> restoreBackup(BackupInfo backup);
}
