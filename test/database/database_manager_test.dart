import 'dart:convert';
import 'dart:io';

import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/database_manager.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/settings/settings_store.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_database.dart';

/// [DatabaseManager] against real SQLite files in a temporary directory:
/// which file it creates, opens and writes into settings.json.
void main() {
  late Directory dir;
  late DatabaseManager manager;

  final currentYear = getCurrentYearAsInt();
  final oldYear = currentYear - 1;

  File dbFile(int year) => File(p.join(dir.path, 'db_$year.db'));
  File settingsFile() => File(p.join(dir.path, SettingsStore.fileName));

  Map<String, dynamic> readSettings() =>
      jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;

  /// Creates a database file outside the manager, like one from an earlier year.
  Future<void> createDatabaseFile(
    File file, {
    List<String> people = const [],
    bool withEntry = false,
  }) async {
    final db = AppDatabase(AppDatabase.openConnection(file));
    for (final name in people) {
      final id = await addTestPerson(db, name);
      if (withEntry) {
        await addTestEntry(db, personId: id, date: DateTime(oldYear, 3, 2));
      }
    }
    await db.forceOpen();
    await db.close();
  }

  /// settings.json as the app left it in [oldYear].
  void writeOldYearSettings() {
    settingsFile().writeAsStringSync(jsonEncode({
      'file_path': dbFile(oldYear).path,
      'current_year': '$oldYear',
      'theme': 'light',
      'language': 'en',
    }));
  }

  Future<List<String>> peopleNames(AppDatabase db) async {
    final people = await db.readDao.watchAllPerson(true).first;
    return people.map((person) => person.name).toList();
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attendly_manager_test_');
    StorageManager.directoryOverride = dir;
    manager = DatabaseManager();
  });

  tearDown(() async {
    await manager.closeDatabase();
    StorageManager.directoryOverride = null;
    dir.deleteSync(recursive: true);
  });

  group('createDatabase', () {
    test('creates the file for the current year and saves it in settings.json', () async {
      await manager.createDatabase();

      expect(dbFile(currentYear).existsSync(), isTrue);
      expect(manager.currentDbPath, dbFile(currentYear).path);
      expect(manager.dbYear, currentYear);
      expect(await manager.databaseConnection.readSchemaVersion(), manager.databaseConnection.schemaVersion);

      final settings = readSettings();
      expect(settings['file_path'], dbFile(currentYear).path);
      expect(settings['current_year'], '$currentYear');
    });

    test('opens the existing file of the current year and keeps its data', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);

      await manager.createDatabase();

      expect(await peopleNames(manager.databaseConnection), ['Anna']);
    });
  });

  group('needsInitialSetup', () {
    test('is true when the storage folder has no database', () async {
      expect(await manager.needsInitialSetup(), isTrue);
    });

    test('is false when the configured database exists', () async {
      await createDatabaseFile(dbFile(currentYear));

      expect(await manager.needsInitialSetup(), isFalse);
    });

    test('is false when the configured database is missing but another one exists', () async {
      await createDatabaseFile(dbFile(oldYear));

      expect(await manager.needsInitialSetup(), isFalse);
    });
  });

  group('openDatabase', () {
    test('fails before any database is open', () {
      expect(() => manager.databaseConnection, throwsA(isA<DatabaseFailedInit>()));
      expect(manager.currentDbPath, isNull);
      expect(manager.dbYear, isNull);
    });

    test('does not create the configured database when it is missing', () async {
      await expectLater(manager.openDatabase(), throwsA(isA<FileSystemException>()));

      expect(dbFile(currentYear).existsSync(), isFalse);
    });

    test('opens the database from settings.json', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);

      await manager.openDatabase();

      expect(manager.currentDbPath, dbFile(currentYear).path);
      expect(await peopleNames(manager.databaseConnection), ['Anna']);
    });

    test('opens a selected file without changing settings.json', () async {
      await createDatabaseFile(dbFile(currentYear), people: ['Anna']);
      await createDatabaseFile(dbFile(oldYear), people: ['Ben']);
      await manager.openDatabase();

      await manager.openDatabase(file: dbFile(oldYear));

      expect(manager.currentDbPath, dbFile(oldYear).path);
      expect(manager.dbYear, oldYear);
      expect(await peopleNames(manager.databaseConnection), ['Ben']);
      expect(readSettings()['file_path'], dbFile(currentYear).path);
    });

    test('does not create a selected file that is missing', () async {
      await expectLater(
        manager.openDatabase(file: dbFile(oldYear)),
        throwsA(isA<FileSystemException>()),
      );

      expect(dbFile(oldYear).existsSync(), isFalse);
    });
  });

  group('year rollover', () {
    test('is not needed in the year of the settings', () async {
      await createDatabaseFile(dbFile(currentYear));

      expect(await manager.checkForYearRollover(), isFalse);
    });

    test('is needed when the settings are from an earlier year and its database exists', () async {
      writeOldYearSettings();
      await createDatabaseFile(dbFile(oldYear));

      expect(await manager.checkForYearRollover(), isTrue);
      expect(await manager.needsInitialSetup(), isFalse);
    });

    test('is not possible when the database of the earlier year is missing', () async {
      writeOldYearSettings();

      expect(await manager.checkForYearRollover(), isFalse);
      expect(await manager.needsInitialSetup(), isTrue);
    });

    test('creates the database of the new year with the people but without the entries', () async {
      writeOldYearSettings();
      await createDatabaseFile(dbFile(oldYear), people: ['Anna', 'Ben'], withEntry: true);
      await manager.checkForYearRollover();

      await manager.performYearRolloverAndOpen();

      expect(manager.currentDbPath, dbFile(currentYear).path);
      final db = manager.databaseConnection;
      expect(await peopleNames(db), unorderedEquals(['Anna', 'Ben']));
      final entries = await db.customSelect('SELECT COUNT(*) AS c FROM daily_entry').getSingle();
      expect(entries.read<int>('c'), 0);

      final settings = readSettings();
      expect(settings['file_path'], dbFile(currentYear).path);
      expect(settings['current_year'], '$currentYear');
      expect(dbFile(oldYear).existsSync(), isTrue);
    });

    test('creates an empty database when no earlier database is known', () async {
      await manager.performYearRolloverAndOpen();

      expect(manager.currentDbPath, dbFile(currentYear).path);
      expect(await peopleNames(manager.databaseConnection), isEmpty);
    });
  });
}
