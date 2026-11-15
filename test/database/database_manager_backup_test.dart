import 'dart:convert';
import 'dart:io';

import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/database_manager.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/settings/settings_store.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_database.dart';

/// The backup as the app uses it: [DatabaseManager] with real database files.
void main() {
  late Directory dir;
  late DatabaseManager manager;

  final currentYear = getCurrentYearAsInt();
  final oldYear = currentYear - 1;

  File dbFile(int year) => File(p.join(dir.path, 'db_$year.db'));
  File latestBackup(int year) => File(p.join(dir.path, 'backup', 'db_$year.latest.bak'));
  File settingsFile() => File(p.join(dir.path, SettingsStore.fileName));

  Map<String, dynamic> readSettings() =>
      jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;

  Future<void> createDatabaseFile(File file, {List<String> people = const []}) async {
    final db = AppDatabase(NativeDatabase(file));
    for (final name in people) {
      await addTestPerson(db, name);
    }
    await db.forceOpen();
    await db.close();
  }

  Future<List<String>> peopleIn(File file) async {
    final db = AppDatabase(NativeDatabase(file));
    try {
      final people = await db.readDao.watchAllPerson(true).first;
      return people.map((person) => person.name).toList();
    } finally {
      await db.close();
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attendly_manager_backup_test_');
    StorageManager.directoryOverride = dir;
    // A long delay: a backup only runs when the test asks for it.
    manager = DatabaseManager(backupDelay: const Duration(minutes: 1));
  });

  tearDown(() async {
    await manager.closeDatabase();
    StorageManager.directoryOverride = null;
    dir.deleteSync(recursive: true);
  });

  group('automatic backup', () {
    test('a database without a backup gets one after it is opened', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);

      await manager.openDatabase();
      expect(latestBackup(currentYear).existsSync(), isFalse, reason: 'the backup waits for its delay');
      await manager.flushBackup();

      expect(await peopleIn(latestBackup(currentYear)), ['Anna']);
    });

    test('a change is in the backup', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await manager.openDatabase();
      await manager.flushBackup();

      await addTestPerson(manager.databaseConnection, 'Ben');
      await Future<void>.delayed(Duration.zero);
      await manager.flushBackup();

      expect(await peopleIn(latestBackup(currentYear)), ['Anna', 'Ben']);
    });

    test('the backup runs by itself after the delay', () async {
      await manager.closeDatabase();
      manager = DatabaseManager(backupDelay: const Duration(milliseconds: 50));
      await createDatabaseFile(dbFile(currentYear));
      await manager.openDatabase();

      await addTestPerson(manager.databaseConnection, 'Anna');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(await peopleIn(latestBackup(currentYear)), ['Anna']);
    });

    test('closing the database writes the waiting backup first', () async {
      await createDatabaseFile(dbFile(currentYear));
      await manager.openDatabase();
      await addTestPerson(manager.databaseConnection, 'Anna');
      await Future<void>.delayed(Duration.zero);

      await manager.closeDatabase();

      expect(await peopleIn(latestBackup(currentYear)), ['Anna']);
    });

    test('a new database gets a backup', () async {
      await manager.createDatabase();
      await manager.flushBackup();

      expect(await peopleIn(latestBackup(currentYear)), isEmpty);
    });

    test('the year rollover backs up the copied people', () async {
      settingsFile().writeAsStringSync(jsonEncode({
        'file_path': dbFile(oldYear).path,
        'current_year': '$oldYear',
        'theme': 'light',
        'language': 'en',
      }));
      await createDatabaseFile(dbFile(oldYear), people: ['Anna', 'Ben']);
      await manager.checkForYearRollover();

      await manager.performYearRolloverAndOpen();
      await manager.flushBackup();

      expect(await peopleIn(latestBackup(currentYear)), unorderedEquals(['Anna', 'Ben']));
    });

    test('a database opened from the list gets its own backup', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await createDatabaseFile(dbFile(oldYear), people: ['Ben']);

      await manager.openDatabase(file: dbFile(oldYear));
      await manager.flushBackup();

      expect(await peopleIn(latestBackup(oldYear)), ['Ben']);
      expect(latestBackup(currentYear).existsSync(), isFalse);
    });
  });

  group('a file that is not a database', () {
    test('fails with DatabaseCorruptedException and leaves no database open', () async {
      dbFile(currentYear).writeAsStringSync('this is not a database ' * 400);

      await expectLater(
        manager.openDatabase(),
        throwsA(isA<DatabaseCorruptedException>()
            .having((e) => e.path, 'path', dbFile(currentYear).path)),
      );

      expect(() => manager.databaseConnection, throwsA(isA<DatabaseFailedInit>()));
      expect(Directory(p.join(dir.path, 'backup')).existsSync(), isFalse);
    });

    test('does not replace the backup of the database it was', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await manager.openDatabase();
      await manager.closeDatabase();
      dbFile(currentYear).writeAsStringSync('this is not a database ' * 400);

      await expectLater(manager.openDatabase(), throwsA(isA<DatabaseCorruptedException>()));

      expect(await peopleIn(latestBackup(currentYear)), ['Anna']);
    });
  });

  group('restoreBackup', () {
    Future<BackupInfo> backupOf(int year) async {
      final backups = await manager.listBackups();
      return backups.firstWhere((b) => b.dbFileName == 'db_$year.db');
    }

    test('puts the backup back and the app can open it again', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await manager.openDatabase();
      await manager.closeDatabase();
      dbFile(currentYear).writeAsStringSync('this is not a database ' * 400);

      await manager.restoreBackup(await backupOf(currentYear));
      await manager.openDatabase();

      expect(manager.currentDbPath, dbFile(currentYear).path);
      final people = await manager.databaseConnection.readDao.watchAllPerson(true).first;
      expect(people.map((person) => person.name), ['Anna']);
    });

    test('closes the open database first', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await manager.openDatabase();
      await manager.flushBackup();

      await manager.restoreBackup(await backupOf(currentYear));

      expect(() => manager.databaseConnection, throwsA(isA<DatabaseFailedInit>()));
    });

    test('makes the restored file the main database when no database is left', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await manager.openDatabase();
      await manager.closeDatabase();
      dbFile(currentYear).deleteSync();
      settingsFile().deleteSync();
      manager = DatabaseManager(backupDelay: const Duration(minutes: 1));
      expect(await manager.needsInitialSetup(), isTrue);

      await manager.restoreBackup(await backupOf(currentYear));

      expect(readSettings()['file_path'], dbFile(currentYear).path);
      expect(readSettings()['current_year'], '$currentYear');
      expect(await manager.checkForYearRollover(), isFalse);
      expect(await manager.needsInitialSetup(), isFalse);
    });

    test('a restored database of an earlier year leads to the year rollover', () async {
      await createDatabaseFile(dbFile(oldYear), people: ['Anna']);
      await manager.openDatabase(file: dbFile(oldYear));
      await manager.closeDatabase();
      dbFile(oldYear).deleteSync();

      await manager.restoreBackup(await backupOf(oldYear));

      expect(readSettings()['file_path'], dbFile(oldYear).path);
      expect(readSettings()['current_year'], '$oldYear');
      expect(await manager.checkForYearRollover(), isTrue);
    });
  });
}
