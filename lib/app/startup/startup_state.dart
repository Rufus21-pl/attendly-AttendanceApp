import 'dart:io';

import 'package:attendly/data/backup/backup_info.dart';

/// What the startup gate shows. Loading is the notifier's AsyncLoading.
sealed class StartupState {
  const StartupState();
}

/// The storage permission is missing. When [permanentlyDenied] the user has
/// to allow it in the system settings.
final class StartupNeedsPermission extends StartupState {
  final bool permanentlyDenied;
  const StartupNeedsPermission({this.permanentlyDenied = false});
}

/// Fresh install: no database file exists yet. [backups] is not empty when
/// backups of an earlier installation are in the storage folder.
final class StartupNeedsSetup extends StartupState {
  final List<BackupInfo> backups;
  const StartupNeedsSetup({this.backups = const []});
}

/// Why the restore screen is shown.
enum RestoreReason {
  /// First start: no database exists, but backups do.
  noDatabase,

  /// The main database file is gone.
  missing,

  /// The main database file cannot be read as a database.
  unreadable,

  /// The main database is open, but the check found damage in it.
  damaged,
}

/// The main database has a problem and a backup can replace it.
/// [backups] is never empty. [error] is set when opening failed.
final class StartupRestoreAvailable extends StartupState {
  final RestoreReason reason;
  final List<BackupInfo> backups;
  final Object? error;
  const StartupRestoreAvailable(this.reason, this.backups, {this.error});
}

/// The year changed: ask whether to create the new year's database.
final class StartupRolloverAvailable extends StartupState {
  const StartupRolloverAvailable();
}

/// The year rollover failed: offer retry or keep the old database.
final class StartupRolloverFailed extends StartupState {
  final Object error;
  const StartupRolloverFailed(this.error);
}

/// A schema migration or the year rollover is running.
final class StartupMigrating extends StartupState {
  const StartupMigrating();
}

/// A database is open; the app shell is shown.
final class StartupReady extends StartupState {
  const StartupReady();
}

/// Opening a database failed, or a page reported a database error.
/// [selectedDb] is set when a database picked in the list failed to open.
final class StartupFailed extends StartupState {
  final Object error;
  final File? selectedDb;
  const StartupFailed(this.error, {this.selectedDb});
}
