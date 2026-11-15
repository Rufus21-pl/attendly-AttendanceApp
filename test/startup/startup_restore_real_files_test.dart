import 'dart:convert';
import 'dart:io';

import 'package:attendly/app/startup/app_startup_notifier.dart';
import 'package:attendly/app/startup/startup_state.dart';
import 'package:attendly/core/permissions/storage_permission_service.dart';
import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/database_manager.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/settings/settings_service.dart';
import 'package:attendly/data/settings/settings_store.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:attendly/features/settings/providers/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../fakes/fake_storage_permission_service.dart';
import '../helpers/test_database.dart';

class _FakeSettingsService extends SettingsService {
  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.light;

  @override
  Future<Locale> getLocale() async => const Locale('en');
}

/// The restore from start to end: real database files, the real database
/// manager and the startup logic. Only the permission and the theme are faked.
void main() {
  late Directory dir;
  late ProviderContainer container;

  final year = getCurrentYearAsInt();
  File dbFile() => File(p.join(dir.path, 'db_$year.db'));
  File settingsFile() => File(p.join(dir.path, SettingsStore.fileName));

  AppStartupNotifier notifier() => container.read(appStartupProvider.notifier);
  Future<StartupState> started() => container.read(appStartupProvider.future);
  StartupState current() => container.read(appStartupProvider).requireValue;

  Future<List<String>> peopleInOpenDatabase() async {
    final people = await container.read(appDatabaseProvider).readDao.watchAllPerson(true).first;
    return people.map((person) => person.name).toList();
  }

  /// A database with [people] that the app used before: it has a backup.
  Future<void> createDatabaseWithBackup(List<String> people) async {
    final manager = DatabaseManager();
    await manager.createDatabase();
    for (final name in people) {
      await addTestPerson(manager.databaseConnection, name);
    }
    await manager.closeDatabase();
    expect(File(p.join(dir.path, 'backup', 'db_$year.latest.bak')).existsSync(), isTrue);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attendly_restore_test_');
    StorageManager.directoryOverride = dir;
    container = ProviderContainer(overrides: [
      storagePermissionServiceProvider.overrideWithValue(FakeStoragePermissionService()),
      settingsProvider.overrideWith(() => SettingsNotifier(_FakeSettingsService())),
    ]);
  });

  tearDown(() async {
    await container.read(databaseProvider.notifier).closeDatabase();
    container.dispose();
    StorageManager.directoryOverride = null;
    dir.deleteSync(recursive: true);
  });

  test('a database file that cannot be read is restored from its backup', () async {
    await createDatabaseWithBackup(['Anna', 'Ben']);
    dbFile().writeAsStringSync('this is not a database ' * 400);

    final state = await started();
    expect(state, isA<StartupRestoreAvailable>().having((s) => s.reason, 'reason', RestoreReason.unreadable));
    final backups = (state as StartupRestoreAvailable).backups;
    expect(backups.map((b) => (b.dbFileName, b.kind)), [('db_$year.db', BackupKind.latest)]);

    await notifier().restoreBackup(backups.first);

    expect(current(), isA<StartupReady>());
    expect(await peopleInOpenDatabase(), ['Anna', 'Ben']);
    expect(container.read(databaseProvider).isTemporaryDb, isFalse);
    final kept = Directory(p.join(dir.path, 'backup'))
        .listSync()
        .where((f) => p.basename(f.path).startsWith('db_$year.damaged-'));
    expect(kept, hasLength(1), reason: 'the file that was replaced is kept');
  });

  test('a deleted database file is restored from its backup', () async {
    await createDatabaseWithBackup(['Anna']);
    dbFile().deleteSync();
    // Another database exists, so this is not a first start.
    File(p.join(dir.path, 'db_${year - 1}.db')).writeAsStringSync('');

    final state = await started();
    expect(state, isA<StartupRestoreAvailable>().having((s) => s.reason, 'reason', RestoreReason.missing));

    await notifier().restoreBackup((state as StartupRestoreAvailable).backups.first);

    expect(current(), isA<StartupReady>());
    expect(await peopleInOpenDatabase(), ['Anna']);
  });

  test('on a first start the backup becomes the main database again', () async {
    await createDatabaseWithBackup(['Anna']);
    dbFile().deleteSync();
    settingsFile().deleteSync();

    final state = await started();
    expect(state, isA<StartupNeedsSetup>().having((s) => s.backups, 'backups', hasLength(1)));

    notifier().showRestoreOptions();
    final restore = current() as StartupRestoreAvailable;
    expect(restore.reason, RestoreReason.noDatabase);
    await notifier().restoreBackup(restore.backups.first);

    expect(current(), isA<StartupReady>());
    expect(await peopleInOpenDatabase(), ['Anna']);
    final settings = jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;
    expect(settings['file_path'], dbFile().path);
    expect(settings['current_year'], '$year');
  });

  test('a healthy database with a backup opens without the restore screen', () async {
    await createDatabaseWithBackup(['Anna']);

    expect(await started(), isA<StartupReady>());
    expect(await peopleInOpenDatabase(), ['Anna']);
  });
}
