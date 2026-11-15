import 'package:drift/native.dart';
// The only way to read an SQLite error that comes from the background isolate.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;

/// SQLite result codes for a file that cannot be read as a database.
const int _sqliteCorrupt = 11;
const int _sqliteNotADatabase = 26;

/// The SQLite error behind [error], or null when it is something else.
///
/// On the device the database runs in a background isolate, where SQLite
/// errors arrive wrapped in a [DriftRemoteException].
SqliteException? sqliteCause(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  return cause is SqliteException ? cause : null;
}

/// True when SQLite reports that the file is damaged or is not a database.
bool isCorruptionError(Object error) {
  final code = sqliteCause(error)?.resultCode;
  return code == _sqliteCorrupt || code == _sqliteNotADatabase;
}
