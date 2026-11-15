import 'dart:io';

import 'package:attendly/core/logging/app_logger.dart';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:path/path.dart' as p;

/// Writes, lists and restores the backup copies of the database files.
///
/// The copies are in `Documents/AttendlyDb/backup/`. Each database has at
/// most two: `db_2026.latest.bak` and `db_2026.previous.bak`. They do not
/// end in `.db`, so the database picker never lists them.
class DatabaseBackupService {
  static const String _tag = 'Backup';

  static const String backupDirName = 'backup';
  static const String _latestSuffix = '.latest.bak';
  static const String _previousSuffix = '.previous.bak';

  /// The first bytes of every SQLite database file.
  static const String _sqliteHeader = 'SQLite format 3';

  /// Only tests pass a [clock].
  DatabaseBackupService({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// True when SQLite finds no damage in the open database.
  Future<bool> isHealthy(AppDatabase db) async {
    try {
      final rows = await db.customSelect('PRAGMA quick_check').get();
      return rows.length == 1 && rows.single.read<String>('quick_check') == 'ok';
    } catch (e, stackTrace) {
      AppLogger.e(_tag, 'The database check failed', e, stackTrace);
      return false;
    }
  }

  /// True when [dbFile] has no backup, or changed since its latest backup.
  Future<bool> needsBackup(File dbFile) async {
    final dir = await _backupDir();
    if (dir == null || !await dbFile.exists()) return false;

    final latest = _latestFile(dir, dbFile);
    if (!await latest.exists()) return true;
    // File times can have a resolution of one second: a change in the same
    // second as the backup counts as newer, so no change is missed.
    return !(await dbFile.lastModified()).isBefore(await latest.lastModified());
  }

  /// Writes a copy of the open database [db], whose file is [dbFile].
  ///
  /// Returns null and keeps the existing copies when the storage folder is
  /// not accessible or the database is damaged: a damaged database must
  /// never replace a good backup.
  Future<BackupInfo?> backupNow(AppDatabase db, File dbFile) async {
    final dir = await _backupDir();
    if (dir == null) {
      AppLogger.e(_tag, 'No backup: storage directory not accessible');
      return null;
    }
    if (!await isHealthy(db)) {
      AppLogger.e(_tag, 'No backup: ${p.basename(dbFile.path)} is damaged, the existing backup is kept');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    final temp = File(p.join(dir.path, '${_baseName(dbFile)}.tmp'));
    if (await temp.exists()) await temp.delete();

    // A complete and consistent copy, also while the app keeps the database open.
    await db.customStatement('VACUUM INTO ?', [temp.path]);

    final latest = _latestFile(dir, dbFile);
    if (await latest.exists() && _isBeforeToday(await latest.lastModified())) {
      // First backup of a new day: keep the last state of the earlier day.
      await latest.rename(_previousFile(dir, dbFile).path);
    }
    await temp.rename(latest.path);

    AppLogger.i(_tag, 'Backup of ${p.basename(dbFile.path)} written in ${stopwatch.elapsedMilliseconds} ms');
    return _describe(latest, BackupKind.latest);
  }

  /// All backup copies, newest first.
  Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupDir(create: false);
    if (dir == null || !await dir.exists()) return [];

    final backups = <BackupInfo>[];
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith(_latestSuffix)) {
          backups.add(await _describe(entity, BackupKind.latest));
        } else if (name.endsWith(_previousSuffix)) {
          backups.add(await _describe(entity, BackupKind.previousDay));
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e(_tag, 'Listing the backups in ${dir.path} failed', e, stackTrace);
      return [];
    }

    backups.sort((a, b) => b.modified.compareTo(a.modified));
    return backups;
  }

  /// Puts [backup] back as its database file in the storage folder and
  /// returns that file. The database must be closed.
  ///
  /// A database file that is already there is not deleted: it moves to the
  /// backup folder with `damaged` and the time in its name.
  Future<File> restore(BackupInfo backup) async {
    final storageDir = await StorageManager.getExternalDocumentsDir();
    final dir = await _backupDir();
    if (storageDir == null || dir == null) {
      throw DatabaseFailedInit('Could not access the storage directory. Please check app permissions.');
    }
    if (!await _isSqliteFile(backup.file)) {
      throw DatabaseCorruptedException(backup.file.path);
    }

    final target = File(p.join(storageDir.path, backup.dbFileName));
    if (await target.exists()) {
      final kept = File(p.join(dir.path, '${_baseName(target)}.damaged-${_timestamp()}.bak'));
      AppLogger.w(_tag, 'Restore: keeping the replaced file as ${p.basename(kept.path)}');
      await target.rename(kept.path);
    }

    // Copy first, then rename: an interrupted copy never looks like a database.
    final temp = File('${target.path}.restore');
    await backup.file.copy(temp.path);
    await temp.rename(target.path);

    AppLogger.i(_tag, 'Restored ${backup.dbFileName} from ${p.basename(backup.file.path)}');
    return target;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Directory?> _backupDir({bool create = true}) async {
    final storageDir = await StorageManager.getExternalDocumentsDir();
    if (storageDir == null) return null;

    final dir = Directory(p.join(storageDir.path, backupDirName));
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _baseName(File dbFile) => p.basenameWithoutExtension(dbFile.path);

  File _latestFile(Directory dir, File dbFile) => File(p.join(dir.path, '${_baseName(dbFile)}$_latestSuffix'));

  File _previousFile(Directory dir, File dbFile) => File(p.join(dir.path, '${_baseName(dbFile)}$_previousSuffix'));

  bool _isBeforeToday(DateTime time) {
    final now = _now();
    return time.isBefore(DateTime(now.year, now.month, now.day));
  }

  Future<BackupInfo> _describe(File file, BackupKind kind) async {
    final name = p.basename(file.path);
    final suffix = kind == BackupKind.latest ? _latestSuffix : _previousSuffix;
    return BackupInfo(
      file: file,
      dbFileName: '${name.substring(0, name.length - suffix.length)}.db',
      kind: kind,
      modified: await file.lastModified(),
      sizeBytes: await file.length(),
    );
  }

  Future<bool> _isSqliteFile(File file) async {
    if (!await file.exists() || await file.length() < _sqliteHeader.length) return false;
    final handle = await file.open();
    try {
      final header = await handle.read(_sqliteHeader.length);
      return String.fromCharCodes(header) == _sqliteHeader;
    } finally {
      await handle.close();
    }
  }

  /// yyyyMMdd-HHmmss, for file names.
  String _timestamp() {
    final now = _now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
