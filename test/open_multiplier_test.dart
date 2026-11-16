import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/tables/enums/category.dart';
import 'package:attendly/data/tables/enums/gender.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// The "open" category can be added several times for one person on one day,
/// for example for an anonymous person that stands for several visitors.
void main() {
  final wednesday = DateTime(2026, 5, 20);
  final monday = DateTime(2026, 5, 18);
  late AppDatabase db;
  late int personId;

  setUp(() async {
    db = createTestDatabase();
    // Born 2010-01-01: age 16 on the test day.
    personId = await addTestPerson(db, 'Anonymous', gender: Gender.f, migration: true);
  });

  tearDown(() => db.close());

  Future<List<DailyEntryData>> entries() => db.readDao.getDailyEntriesByPersonId(personId);

  group('insertDailyEntry with the category open', () {
    test('multiplier 3 inserts 3 entries and counts 3 in the weekly stats', () async {
      await db.insertDao.insertDailyEntry(
        personId: personId,
        date: wednesday,
        category: Category.open,
        multiplier: 3,
      );

      final saved = await entries();
      expect(saved.length, 3);
      expect(saved.every((e) => e.category == Category.open), true);
      expect(saved.map((e) => e.recordId).toList()..sort(), [1, 2, 3]);

      final weekly = (await db.readDao.watchWeeklyEntryByDate(monday).first)!;
      expect(weekly.age_14_17, 3);
      expect(weekly.allF, 3);
      expect(weekly.openFemale, 3);
      expect(weekly.migrationFemale, 3);
    });

    test('a second entry on the same day is added', () async {
      await db.insertDao.insertDailyEntry(personId: personId, date: wednesday, category: Category.open);
      await db.insertDao.insertDailyEntry(personId: personId, date: wednesday, category: Category.open);

      expect((await entries()).length, 2);

      final weekly = (await db.readDao.watchWeeklyEntryByDate(monday).first)!;
      expect(weekly.openFemale, 2);
    });

    test('a later insert with a multiplier continues after the existing entries', () async {
      await db.insertDao.insertDailyEntry(personId: personId, date: wednesday, category: Category.open, multiplier: 2);
      await db.insertDao.insertDailyEntry(personId: personId, date: wednesday, category: Category.open, multiplier: 2);

      final saved = await entries();
      expect(saved.map((e) => e.recordId).toList()..sort(), [1, 2, 3, 4]);
    });
  });

  group('several open entries on one day', () {
    setUp(() => db.insertDao.insertDailyEntry(
          personId: personId,
          date: wednesday,
          category: Category.open,
          multiplier: 3,
        ));

    test('hasOpenCategoryForDate is true and does not throw', () async {
      expect(await db.readDao.hasOpenCategoryForDate(personId, wednesday), true);
      expect(await db.readDao.hasOpenCategoryForDate(personId, monday), false);
    });

    test('editing another entry to open is still refused as a duplicate', () async {
      await db.insertDao.insertDailyEntry(personId: personId, date: wednesday, category: Category.other);
      final other = (await entries()).firstWhere((e) => e.category == Category.other);

      await expectLater(
        () => db.updateDao.updateDailyEntry(
          recordID: other.recordId,
          date: wednesday,
          personId: personId,
          newCategory: Category.open,
        ),
        throwsA(isA<DuplicateDailyEntryException>()),
      );

      final saved = await entries();
      expect(saved.where((e) => e.category == Category.open).length, 3);
      expect(saved.where((e) => e.category == Category.other).length, 1);
    });

    test('deleting one entry removes one from the weekly stats', () async {
      await db.deleteDao.deleteDailyEntry(2, personId, wednesday);

      expect((await entries()).map((e) => e.recordId).toList()..sort(), [1, 3]);

      final weekly = (await db.readDao.watchWeeklyEntryByDate(monday).first)!;
      expect(weekly.openFemale, 2);
      expect(weekly.migrationFemale, 2);
      expect(weekly.allF, 2);
    });
  });
}
