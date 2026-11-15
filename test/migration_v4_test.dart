import 'dart:io';

import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/database_manager.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:attendly/data/tables/enums/category.dart';
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v3.dart' as v3;
import 'helpers/test_database.dart';

/// Schema v4: daily_entry.person_id references directory_people.id.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  Future<void> insertPerson(GeneratedDatabase db, int id, String name) {
    return db.customStatement(
      "INSERT INTO directory_people (id, name, birthday, gender, migration, migration_background) "
      "VALUES ($id, '$name', '2010-01-01T00:00:00.000', 'f', 0, '')",
    );
  }

  Future<void> insertEntry(GeneratedDatabase db, {required int recordId, required int personId}) {
    return db.customStatement(
      "INSERT INTO daily_entry (record_id, date, person_id, category, description) "
      "VALUES ($recordId, '2026-03-02T00:00:00.000', $personId, 'open', NULL)",
    );
  }

  Future<List<int>> entryPersonIds(GeneratedDatabase db) async {
    final rows = await db.customSelect('SELECT person_id FROM daily_entry ORDER BY person_id').get();
    return rows.map((row) => row.read<int>('person_id')).toList();
  }

  final refusedByForeignKey = throwsA(predicate(
    (Object error) => error.toString().contains('FOREIGN KEY constraint failed'),
    'is refused by the foreign key',
  ));

  group('migration v3 -> v4', () {
    test('matches the v4 schema', () async {
      final connection = await verifier.startAt(3);
      final db = AppDatabase(connection);

      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });

    test('keeps people and entries', () async {
      final schema = await verifier.schemaAt(3);
      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await insertPerson(oldDb, 1, 'Anna');
      await insertEntry(oldDb, recordId: 1, personId: 1);
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      final people = await db.readDao.watchAllPerson(true).first;
      expect(people.map((p) => p.name), ['Anna']);
      final entries = await db.readDao.getDailyEntriesByPersonId(1);
      expect(entries.map((e) => (e.date, e.category)), [(DateTime(2026, 3, 2), Category.open)]);
      await db.close();
    });

    test('removes entries without a person and keeps the other entries', () async {
      final schema = await verifier.schemaAt(3);
      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await insertPerson(oldDb, 1, 'Anna');
      await insertEntry(oldDb, recordId: 1, personId: 1);
      // v3 has no foreign key: an entry can point to a person that is gone.
      await insertEntry(oldDb, recordId: 2, personId: 99);
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      expect(await entryPersonIds(db), [1]);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
    });

    test('the migrated database refuses an entry for a person that does not exist', () async {
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      await expectLater(insertEntry(db, recordId: 1, personId: 99), refusedByForeignKey);
      await db.close();
    });
  });

  test('the app migrates a v3 database file when it opens it', () async {
    final dir = Directory.systemTemp.createTempSync('attendly_migration_v4_test_');
    StorageManager.directoryOverride = dir;
    final manager = DatabaseManager();
    addTearDown(() async {
      await manager.closeDatabase();
      StorageManager.directoryOverride = null;
      dir.deleteSync(recursive: true);
    });

    // The file that settings.json points to by default, as an older app version left it.
    final file = File(p.join(dir.path, 'db_${getCurrentYearAsInt()}.db'));
    final oldDb = v3.DatabaseAtV3(NativeDatabase(file));
    await insertPerson(oldDb, 1, 'Anna');
    await insertEntry(oldDb, recordId: 1, personId: 1);
    await insertEntry(oldDb, recordId: 2, personId: 99);
    await oldDb.close();

    var migrationAnnounced = false;
    await manager.openDatabase(onMigrationStarted: () async => migrationAnnounced = true);

    final db = manager.databaseConnection;
    expect(migrationAnnounced, isTrue);
    expect(await db.readSchemaVersion(), 4);
    expect(await entryPersonIds(db), [1]);
    await expectLater(insertEntry(db, recordId: 3, personId: 99), refusedByForeignKey);
  });

  group('a new database', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('refuses an entry for a person that does not exist', () async {
      await expectLater(insertEntry(db, recordId: 1, personId: 99), refusedByForeignKey);

      expect(await entryPersonIds(db), isEmpty);
    });

    test('refuses to delete a person that still has entries', () async {
      await insertPerson(db, 1, 'Anna');
      await insertEntry(db, recordId: 1, personId: 1);

      await expectLater(
        db.customStatement('DELETE FROM directory_people WHERE id = 1'),
        refusedByForeignKey,
      );
    });

    test('the delete DAO still deletes a person together with the entries', () async {
      final id = await addTestPerson(db, 'Anna');
      await addTestEntry(db, personId: id, date: DateTime(2026, 3, 2));

      await db.deleteDao.deleteDirPerson(id);

      expect(await db.readDao.getPersonById(id), isNull);
      expect(await entryPersonIds(db), isEmpty);
    });
  });
}
