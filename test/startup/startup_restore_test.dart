import 'dart:io';

import 'package:attendly/app/startup/app_startup_notifier.dart';
import 'package:attendly/app/startup/startup_state.dart';
import 'package:attendly/core/permissions/storage_permission_service.dart';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/settings/settings_service.dart';
import 'package:attendly/features/settings/providers/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_database_manager.dart';
import '../fakes/fake_storage_permission_service.dart';

class _FakeSettingsService extends SettingsService {
  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.light;

  @override
  Future<Locale> getLocale() async => const Locale('en');
}

BackupInfo _backup(String dbFileName, BackupKind kind) => BackupInfo(
      file: File('/storage/emulated/0/Documents/AttendlyDb/backup/$dbFileName.${kind.name}.bak'),
      dbFileName: dbFileName,
      kind: kind,
      modified: DateTime(2026, 11, 15, 23, 56),
      sizeBytes: 200704,
    );

/// When startup offers a backup, and what a restore does.
void main() {
  const mainDbPath = '/storage/emulated/0/Documents/AttendlyDb/db_2026.db';
  final latest = _backup('db_2026.db', BackupKind.latest);
  final previous = _backup('db_2026.db', BackupKind.previousDay);
  final otherYear = _backup('db_2025.db', BackupKind.latest);

  late FakeDatabaseManager manager;
  late ProviderContainer container;

  setUp(() {
    manager = FakeDatabaseManager();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith(() => DatabaseNotifier(manager)),
      storagePermissionServiceProvider.overrideWithValue(FakeStoragePermissionService()),
      settingsProvider.overrideWith(() => SettingsNotifier(_FakeSettingsService())),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await manager.closeDatabase();
  });

  AppStartupNotifier notifier() => container.read(appStartupProvider.notifier);
  Future<StartupState> started() => container.read(appStartupProvider.future);
  StartupState current() => container.read(appStartupProvider).requireValue;

  group('a database file that cannot be read', () {
    setUp(() => manager.openError = DatabaseCorruptedException(mainDbPath));

    test('offers the backups of that database, not of other years', () async {
      manager.backups = [latest, otherYear, previous];

      final state = await started();

      expect(state, isA<StartupRestoreAvailable>()
          .having((s) => s.reason, 'reason', RestoreReason.unreadable)
          .having((s) => s.backups, 'backups', [latest, previous])
          .having((s) => s.error, 'error', isA<DatabaseCorruptedException>()));
    });

    test('shows the failed screen when it has no backup, as before', () async {
      manager.backups = [otherYear];

      expect(await started(), isA<StartupFailed>());
    });
  });

  group('a main database file that is missing', () {
    setUp(() => manager.openError = const DatabaseFileMissingException(mainDbPath));

    test('offers its backups', () async {
      manager.backups = [latest];

      expect(await started(), isA<StartupRestoreAvailable>()
          .having((s) => s.reason, 'reason', RestoreReason.missing)
          .having((s) => s.backups, 'backups', [latest]));
    });

    test('shows the failed screen when it has no backup, as before', () async {
      expect(await started(), isA<StartupFailed>());
    });
  });

  test('another error shows the failed screen, also when a backup exists', () async {
    manager
      ..openError = Exception('disk failure')
      ..backups = [latest];

    expect(await started(), isA<StartupFailed>());
  });

  group('a database that opens but is damaged', () {
    setUp(() => manager.damaged = true);

    test('offers its backups and keeps the database open', () async {
      manager.backups = [latest, previous];

      expect(await started(), isA<StartupRestoreAvailable>()
          .having((s) => s.reason, 'reason', RestoreReason.damaged)
          .having((s) => s.backups, 'backups', [latest, previous]));
      expect(container.read(databaseProvider).isReady, isTrue);
    });

    test('the user can continue with it', () async {
      manager.backups = [latest];
      await started();

      await notifier().continueWithDamagedDatabase();

      expect(current(), isA<StartupReady>());
      expect(manager.calls, isNot(contains(startsWith('restoreBackup'))));
    });

    test('opens as before when it has no backup', () async {
      expect(await started(), isA<StartupReady>());
    });
  });

  group('first start', () {
    setUp(() => manager.initialSetupNeeded = true);

    test('without backups shows the setup screen, as before', () async {
      expect(await started(), isA<StartupNeedsSetup>().having((s) => s.backups, 'backups', isEmpty));

      notifier().showRestoreOptions();

      expect(current(), isA<StartupNeedsSetup>());
    });

    test('with backups the setup screen can show all of them', () async {
      manager.backups = [latest, otherYear];
      expect(await started(), isA<StartupNeedsSetup>()
          .having((s) => s.backups, 'backups', [latest, otherYear]));

      notifier().showRestoreOptions();

      expect(current(), isA<StartupRestoreAvailable>()
          .having((s) => s.reason, 'reason', RestoreReason.noDatabase)
          .having((s) => s.backups, 'backups', [latest, otherYear]));
    });

    test('a restored backup becomes the main database and the app is ready', () async {
      manager.backups = [latest];
      await started();
      notifier().showRestoreOptions();

      await notifier().restoreBackup(latest);

      expect(current(), isA<StartupReady>());
      expect(manager.calls, containsAllInOrder(['restoreBackup(db_2026.db)', 'openDatabase']));
      expect(container.read(databaseProvider).currentDbPath, mainDbPath);
      expect(container.read(databaseProvider).isTemporaryDb, isFalse);
    });

    test('creating a database is still possible from the restore screen', () async {
      manager.backups = [latest];
      await started();
      notifier().showRestoreOptions();

      await notifier().createDatabase();

      expect(current(), isA<StartupReady>());
      expect(manager.calls, contains('createDatabase'));
    });
  });

  group('restore', () {
    test('replaces the file that cannot be read and opens the database', () async {
      manager
        ..openError = DatabaseCorruptedException(mainDbPath)
        ..backups = [latest, previous];
      await started();

      await notifier().restoreBackup(previous);

      expect(current(), isA<StartupReady>());
      expect(manager.calls.last, 'openDatabase');
      expect(manager.calls, contains('restoreBackup(db_2026.db)'));
    });

    test('runs the year check again, so an earlier year leads to the rollover question', () async {
      manager
        ..initialSetupNeeded = true
        ..backups = [otherYear];
      await started();
      notifier().showRestoreOptions();
      manager.rolloverNeeded = true;

      await notifier().restoreBackup(otherYear);

      expect(current(), isA<StartupRolloverAvailable>());
    });

    test('a failed restore is reported and the screen matches the files again', () async {
      manager
        ..openError = DatabaseCorruptedException(mainDbPath)
        ..backups = [latest]
        ..restoreError = const FileSystemException('disk full');
      await started();

      await expectLater(notifier().restoreBackup(latest), throwsA(isA<FileSystemException>()));

      expect(current(), isA<StartupRestoreAvailable>()
          .having((s) => s.reason, 'reason', RestoreReason.unreadable));
    });
  });
}
