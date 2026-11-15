import 'dart:io';

/// Which of the two backup copies of a database a file is.
enum BackupKind {
  /// Written a few seconds after the last change.
  latest,

  /// The state at the end of the last earlier day that had changes.
  previousDay,
}

/// One backup file of a database.
class BackupInfo {
  final File file;

  /// The database file the backup belongs to, e.g. `db_2026.db`.
  final String dbFileName;

  final BackupKind kind;

  /// When the backup was written.
  final DateTime modified;

  final int sizeBytes;

  const BackupInfo({
    required this.file,
    required this.dbFileName,
    required this.kind,
    required this.modified,
    required this.sizeBytes,
  });

  /// The year in the database file name, e.g. 2026 for `db_2026.db`.
  int? get dbYear {
    final match = RegExp(r'db_(\d{4})').firstMatch(dbFileName);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
