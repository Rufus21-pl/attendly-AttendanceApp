import 'dart:io';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/database_manager.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/database/database_manager_interface.dart';
import 'package:attendly/data/database/database_state.dart';
import 'package:attendly/core/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/misc.dart' show ProviderException;
 
 
class DatabaseNotifier extends Notifier<DatabaseState> {
  /// [manager] is only passed in tests; the app always uses [DatabaseManager].
  DatabaseNotifier([DatabaseManagerInterface? manager])
      : _manager = manager ?? DatabaseManager();

  final DatabaseManagerInterface _manager;

  /// No database is open until startup opens or creates one.
  @override
  DatabaseState build() => const DatabaseState();
 
 
  /// Normal startup: check if we need a year rollover first.
  /// Returns true if a rollover is needed, false if not.
  Future<bool> checkForYearRollover() {
    return _manager.checkForYearRollover();
  }

  /// True on a fresh install where no database has been created yet.
  Future<bool> needsInitialSetup() {
    return _manager.needsInitialSetup();
  }
 
  /// Opens the default DB (path comes from settings.json inside the manager).
  /// Marks state as ready when done.
  Future<void> openDatabase({File? file, Future<void> Function()? onMigrationStarted}) async {
    await _manager.openDatabase(file: file, onMigrationStarted: onMigrationStarted);
    state = DatabaseState(
      manager:           _manager,
      isTemporaryDb:     file != null, 
      showNewYearBanner: false,
      isReady:           true,
    );
  }
 
  /// Opens the default DB but keeps the "new year banner" visible.
  Future<void> openDatabaseWithBanner({Future<void> Function()? onMigrationStarted}) async {
    await _manager.openDatabase(onMigrationStarted: onMigrationStarted);
    state = DatabaseState(
      manager:           _manager,
      isTemporaryDb:     false,
      showNewYearBanner: true,
      isReady:           true,
    );
  }
 
  /// Creates a fresh DB for the current year.
  Future<void> createDatabase() async {
    await _manager.createDatabase();
    state = DatabaseState(
      manager:           _manager,
      isTemporaryDb:     false,
      showNewYearBanner: false,
      isReady:           true,
    );
  }
 
  /// Year rollover: migrates people from the old DB into a brand-new one.
  /// On success the banner stays hidden; on failure the caller shows a banner.
  Future<void> performYearRolloverAndOpen({Future<void> Function()? onMigrationStarted}) async {
    await _manager.performYearRolloverAndOpen(onMigrationStarted: onMigrationStarted);
    state = DatabaseState(
      manager:           _manager,
      isTemporaryDb:     false,
      showNewYearBanner: false,
      isReady:           true,
    );
  }
 
  /// Marks the new-year banner as dismissed without changing anything else.
  void setShowNewYearBanner(bool value) {
    if (state.showNewYearBanner == value) return;
    state = state.copyWith(showNewYearBanner: value);
  }
 
  /// Read the raw settings.json for the secret debug menu.
  Future<String> getSettingsJsonContent() {
    return _manager.getSettingsJsonContent();
  }
 
  /// True when the open database was opened, but the check found damage.
  bool get isOpenDatabaseDamaged => _manager.isOpenDatabaseDamaged;

  /// The backup copies of all databases, newest first.
  Future<List<BackupInfo>> listBackups() {
    return _manager.listBackups();
  }

  /// The backup copies of the main database from settings.json, newest
  /// first. Known after the startup checks, also when it cannot be opened.
  Future<List<BackupInfo>> listBackupsOfCurrentDatabase() async {
    final path = _manager.currentDbPath;
    if (path == null) return [];
    final fileName = p.basename(path);
    final backups = await _manager.listBackups();
    return backups.where((backup) => backup.dbFileName == fileName).toList();
  }

  /// Closes the open database and puts [backup] back as the main database.
  /// The caller opens it with the normal startup checks.
  Future<void> restoreBackup(BackupInfo backup) async {
    state = const DatabaseState();
    await _manager.restoreBackup(backup);
  }

  /// Writes a backup of the open database now and waits for it.
  Future<void> backupNow() {
    return _manager.backupNow();
  }

  /// Writes a backup that is waiting for its delay now. Called when the app
  /// goes to the background, where Android can stop it at any time.
  Future<void> flushBackup() {
    return _manager.flushBackup();
  }

  /// Closes the underlying DB and resets state to "not ready".
  /// Called before switching to a different DB file.
  Future<void> closeDatabase() async {
    state = const DatabaseState(); // isReady = false immediately
    await _manager.closeDatabase();
  }

  void reportDatabaseError(Object error, [StackTrace? stackTrace]) {
    AppLogger.e('Database', 'A page reported a database error, showing the error screen '
        '(db: ${state.currentDbPath ?? 'none'})', error, stackTrace);
    state = DatabaseState(dbError: error); // manager=null, isReady=false
  }
}
/// The provider you read / watch everywhere.
final databaseProvider =
    NotifierProvider<DatabaseNotifier, DatabaseState>(DatabaseNotifier.new);
 


final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final state = ref.watch(databaseProvider);
  
  if (state.manager == null || !state.isReady) {
    throw const DatabaseNotReadyException();
  }
  
  return state.manager!.databaseConnection;
});

/// True when [error] is a [DatabaseNotReadyException], also when Riverpod
/// wrapped it.
///
/// [appDatabaseProvider] throws the exception while no database is open. A
/// provider or a widget that reads a failed provider does not get that error
/// itself: Riverpod puts it into a [ProviderException], once for every
/// provider in between. Use this instead of `error is DatabaseNotReadyException`.
bool isDatabaseNotReady(Object? error) {
  var cause = error;
  while (cause is ProviderException) {
    cause = cause.exception;
  }
  return cause is DatabaseNotReadyException;
}

/// The schema version of the open database file, e.g. for the settings page.
/// Fails with [DatabaseNotReadyException] while no database is open.
final databaseSchemaVersionProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(appDatabaseProvider).readSchemaVersion();
});

/// The newest backup of the open database, or null when it has none or no
/// database is open. Read when a page shows it, and again after
/// `ref.invalidate`.
final lastBackupProvider = FutureProvider.autoDispose<BackupInfo?>((ref) async {
  final state = ref.watch(databaseProvider);
  if (!state.isReady) return null;

  final backups = await ref.read(databaseProvider.notifier).listBackupsOfCurrentDatabase();
  return backups.where((backup) => backup.kind == BackupKind.latest).firstOrNull;
});
