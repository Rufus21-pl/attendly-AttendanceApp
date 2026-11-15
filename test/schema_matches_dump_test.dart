import 'package:attendly/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v3.dart' as v3;

/// A database that the app creates today must have the same tables and
/// indexes as the dump of its schema version in drift_schemas/.
///
/// A new database is created from the table classes, an old one keeps what it
/// has. If the two differ, e.g. after a generator upgrade adds a constraint,
/// new and old database files of the same schema version behave differently.
void main() {
  /// Table and index definitions as SQLite stores them, by name. Quotes and
  /// spaces are removed: the dump and the app write them differently, e.g.
  /// `PRIMARY KEY(date)` and `PRIMARY KEY ("date")`.
  Future<Map<String, String>> readSchema(GeneratedDatabase db) async {
    final rows = await db.customSelect(
      "SELECT name, sql FROM sqlite_master "
      "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY name",
    ).get();
    return {
      for (final row in rows)
        row.read<String>('name'): row.read<String>('sql').replaceAll(RegExp(r'["\s]'), ''),
    };
  }

  test('a new database has the schema of the v3 dump', () async {
    final created = AppDatabase.testInstance();
    final verifier = SchemaVerifier(GeneratedHelper());
    final fromDump = v3.DatabaseAtV3((await verifier.schemaAt(3)).newConnection());

    expect(created.schemaVersion, 3, reason: 'compare with the dump of the current schema version');
    expect(await readSchema(created), await readSchema(fromDump));

    await created.close();
    await fromDump.close();
  });
}
