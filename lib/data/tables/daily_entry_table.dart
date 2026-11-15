import 'package:attendly/data/tables/date_only_converter.dart';
import 'package:attendly/data/tables/enums/category.dart';
import 'package:drift/drift.dart';

/// Per-day queries filter by date (the primary key starts with record_id, so it
/// cannot serve them); per-person counts, lookups and deletes filter by person.
@TableIndex(name: 'daily_entry_date_person', columns: {#date, #personId})
@TableIndex(name: 'daily_entry_person', columns: {#personId})
class DailyEntry extends Table{
  IntColumn get recordId => integer()();
  TextColumn get date => text().map(const DateOnlyConverter())();
  /// The id of a row in directory_people. There is no REFERENCES constraint:
  /// no database file has one (schema v1 to v3), and adding it needs a new
  /// schema version with a migration. The DAOs keep the rows consistent.
  IntColumn get personId => integer()();
  TextColumn get category => textEnum<Category>()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {recordId, date, personId};
}