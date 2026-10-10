import 'package:attendly/data/dao/shared_dao_logic.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/tables/daily_entry_table.dart';
import 'package:attendly/data/tables/directory_people_table.dart';
import 'package:attendly/data/tables/enums/category.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/remote.dart' show DriftRemoteException;

part 'insert_dao.g.dart';

@DriftAccessor(tables: [DirectoryPeople, DailyEntry])
class InsertDao extends DatabaseAccessor<AppDatabase> with _$InsertDaoMixin, SharedDaoLogic {
  InsertDao(super.db);

  // --- 1. All People Table Insertion ---
  /// Replaces allPeopleTable. Inserts a person into the directory.
  Future<void> insertDirPerson(DirectoryPeopleCompanion person) async {
    final name = person.name.value;
    // Checked before inserting: a failed insert logs the person's data with
    // the SQL statement.
    if (await db.readDao.isPersonNameTaken(name)) {
      throw DuplicatePersonException(name);
    }

    try {
      await into(directoryPeople).insert(person);
    } catch (e) {
      // On the device the database runs in a background isolate, where
      // SQLite errors arrive wrapped in a DriftRemoteException.
      final cause = e is DriftRemoteException ? e.remoteCause : e;
      if (cause is! SqliteException) rethrow;
      if (cause.extendedResultCode == 2067) {
        throw DuplicatePersonException(name);
      }
      throw DatabaseOperationException("Database constraint failed", originalException: cause);
    }
  }

  // --- 2. Daily Table Insertion ---
  /// Replaces dailyTable.
  Future<void> insertDailyEntry({
    required int personId,
    required DateTime date,
    required Category category,
    String? description,
    int multiplier = 1
  }) async {
    if (multiplier < 1) {
      throw ArgumentError.value(multiplier, 'multiplier', 'must be >= 1');
    }

    if (category == Category.open && multiplier != 1) {
      throw ArgumentError.value(multiplier, 'multiplier', 'open allows only one entry per person per day');
    }

    await transaction(() async {
      // Check if person exists
      final person = await db.readDao.getPersonById(personId);
      if (person == null) {
        throw PersonNotFoundException(personId);
      }

      if (category == Category.open) {        
        if (await db.readDao.hasOpenCategoryForDate(personId, date)) {
          throw DuplicateDailyEntryException();
        }
      }

      for (int i = 0; i < multiplier; i++) {

        final latestId = await _getLatestRecordID(date);

        await into(dailyEntry).insert(DailyEntryCompanion.insert(
          recordId: latestId,
          date: date,
          personId: personId,
          category: category,
          description: Value(description),
        ));

        await _updateWeeklyStats(person, category, date);
      }
    });
  }

  // --- Helper Methods ---

  Future<int> _getLatestRecordID(DateTime date) async {
    final query = selectOnly(dailyEntry)
      ..addColumns([dailyEntry.recordId.max()])
      ..where(dailyEntry.date.equals(db.dateOnlyConverter.toSql(date)));
    
    final result = await query.map((row) => row.read(dailyEntry.recordId.max())).getSingle();
    return (result ?? 0) + 1;
  }

  Future<void> _updateWeeklyStats(DirectoryPeopleData person, Category category, DateTime date) async {
    final weekDate = getFirstDateOfWeek(date);
    final age = calcAge(date, person.birthday);

    await db.updateDao.updateWeeklyTableCounters(
      weekDate: weekDate,
      age: age,
      gender: person.gender,
      category: category,
      migration: person.migration,
      isAddition: true,
    );
  }
}