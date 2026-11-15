import 'dart:io';

import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/backup/database_backup_service.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_database.dart';

/// [DatabaseBackupService] against real database files in a temporary directory.
void main() {
  late Directory dir;
  late File dbFile;
  late AppDatabase db;
  late DateTime now;
  late DatabaseBackupService service;

  File backupFile(String name) => File(p.join(dir.path, 'backup', name));
  late File latest;
  late File previous;

  /// The names of the people in the database file [file].
  Future<List<String>> peopleIn(File file) async {
    final copy = AppDatabase(NativeDatabase(file));
    try {
      final people = await copy.readDao.watchAllPerson(true).first;
      return people.map((person) => person.name).toList();
    } finally {
      await copy.close();
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attendly_backup_test_');
    StorageManager.directoryOverride = dir;
    dbFile = File(p.join(dir.path, 'db_2026.db'));
    latest = backupFile('db_2026.latest.bak');
    previous = backupFile('db_2026.previous.bak');
    db = AppDatabase(NativeDatabase(dbFile));
    now = DateTime.now();
    service = DatabaseBackupService(clock: () => now);
  });

  tearDown(() async {
    await db.close();
    StorageManager.directoryOverride = null;
    dir.deleteSync(recursive: true);
  });

  group('backupNow', () {
    test('writes a copy of the open database into the backup folder', () async {
      await addTestPerson(db, 'Anna');

      final backup = await service.backupNow(db, dbFile);

      expect(backup!.file.path, latest.path);
      expect(backup.kind, BackupKind.latest);
      expect(backup.dbFileName, 'db_2026.db');
      expect(backup.dbYear, 2026);
      expect(backup.sizeBytes, greaterThan(0));
      expect(await peopleIn(latest), ['Anna']);
    });

    test('replaces the latest copy on the same day and keeps no older copy', () async {
      await addTestPerson(db, 'Anna');
      await service.backupNow(db, dbFile);
      await addTestPerson(db, 'Ben');

      await service.backupNow(db, dbFile);

      expect(await peopleIn(latest), ['Anna', 'Ben']);
      expect(previous.existsSync(), isFalse);
    });

    test('keeps the last copy of an earlier day as the previous copy', () async {
      await addTestPerson(db, 'Anna');
      await service.backupNow(db, dbFile);
      latest.setLastModifiedSync(now.subtract(const Duration(days: 1)));
      await addTestPerson(db, 'Ben');

      await service.backupNow(db, dbFile);

      expect(await peopleIn(previous), ['Anna']);
      expect(await peopleIn(latest), ['Anna', 'Ben']);
    });

    test('a third day replaces the previous copy', () async {
      await addTestPerson(db, 'Anna');
      await service.backupNow(db, dbFile);
      latest.setLastModifiedSync(now.subtract(const Duration(days: 2)));
      await addTestPerson(db, 'Ben');
      await service.backupNow(db, dbFile);
      latest.setLastModifiedSync(now.subtract(const Duration(days: 1)));
      await addTestPerson(db, 'Carla');

      await service.backupNow(db, dbFile);

      expect(await peopleIn(previous), ['Anna', 'Ben']);
      expect(await peopleIn(latest), ['Anna', 'Ben', 'Carla']);
    });

    test('leaves no temporary file and does not show up as a database file', () async {
      await service.backupNow(db, dbFile);

      final names = Directory(p.join(dir.path, 'backup')).listSync().map((f) => p.basename(f.path));
      expect(names, ['db_2026.latest.bak']);
      final dbFiles = await StorageManager.listDbFiles();
      expect(dbFiles.map((f) => p.basename(f.path)), ['db_2026.db']);
    });
  });

  group('a damaged database', () {
    /// Fills the database, then overwrites pages in the middle of the file.
    Future<void> damageDatabase() async {
      for (var i = 0; i < 400; i++) {
        await addTestPerson(db, 'Person number $i with a long name to fill pages');
      }
      await db.close();

      final bytes = dbFile.readAsBytesSync();
      expect(bytes.length, greaterThan(4096 * 6), reason: 'the file needs several pages');
      for (var i = 4096 * 2; i < 4096 * 5; i++) {
        bytes[i] = 0xFF;
      }
      dbFile.writeAsBytesSync(bytes);
      db = AppDatabase(NativeDatabase(dbFile));
    }

    test('is reported as not healthy', () async {
      expect(await service.isHealthy(db), isTrue);

      await damageDatabase();

      expect(await service.isHealthy(db), isFalse);
    });

    test('never replaces a good backup', () async {
      await addTestPerson(db, 'Anna');
      await service.backupNow(db, dbFile);
      final goodBackup = latest.readAsBytesSync();
      await damageDatabase();

      final backup = await service.backupNow(db, dbFile);

      expect(backup, isNull);
      expect(latest.readAsBytesSync(), goodBackup);
      expect(previous.existsSync(), isFalse);
    });
  });

  group('needsBackup', () {
    test('is true while the database has no backup', () async {
      await db.forceOpen();

      expect(await service.needsBackup(dbFile), isTrue);
    });

    test('is false when the backup is newer than the database', () async {
      await service.backupNow(db, dbFile);
      dbFile.setLastModifiedSync(latest.lastModifiedSync().subtract(const Duration(seconds: 10)));

      expect(await service.needsBackup(dbFile), isFalse);
    });

    test('is true when the database changed after the backup', () async {
      await service.backupNow(db, dbFile);
      dbFile.setLastModifiedSync(latest.lastModifiedSync().add(const Duration(seconds: 10)));

      expect(await service.needsBackup(dbFile), isTrue);
    });
  });

  group('listBackups', () {
    test('is empty when nothing was backed up', () async {
      expect(await service.listBackups(), isEmpty);
    });

    test('lists the latest and the previous copy, newest first, and no other file', () async {
      await service.backupNow(db, dbFile);
      latest.setLastModifiedSync(now.subtract(const Duration(days: 1)));
      await service.backupNow(db, dbFile);
      backupFile('db_2026.damaged-20260101-120000.bak').writeAsStringSync('old file');
      backupFile('notes.txt').writeAsStringSync('not a backup');

      final backups = await service.listBackups();

      expect(backups.map((b) => (b.dbFileName, b.kind)), [
        ('db_2026.db', BackupKind.latest),
        ('db_2026.db', BackupKind.previousDay),
      ]);
    });
  });

  group('restore', () {
    test('puts the backup back as the database file', () async {
      await addTestPerson(db, 'Anna');
      final backup = await service.backupNow(db, dbFile);
      await db.close();
      dbFile.deleteSync();

      final restored = await service.restore(backup!);

      expect(restored.path, dbFile.path);
      expect(await peopleIn(dbFile), ['Anna']);
      expect(latest.existsSync(), isTrue, reason: 'the backup itself stays');
    });

    test('keeps the file it replaces in the backup folder', () async {
      await addTestPerson(db, 'Anna');
      final backup = await service.backupNow(db, dbFile);
      await db.close();
      dbFile.writeAsStringSync('this is not a database any more');

      await service.restore(backup!);

      final kept = Directory(p.join(dir.path, 'backup'))
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('db_2026.damaged-'))
          .toList();
      expect(kept, hasLength(1));
      expect(kept.single.readAsStringSync(), 'this is not a database any more');
      expect(await peopleIn(dbFile), ['Anna']);
      expect((await StorageManager.listDbFiles()).map((f) => p.basename(f.path)), ['db_2026.db']);
    });

    test('refuses a backup file that is not a database and changes nothing', () async {
      await addTestPerson(db, 'Anna');
      await db.close();
      final before = dbFile.readAsBytesSync();
      Directory(p.join(dir.path, 'backup')).createSync();
      latest.writeAsStringSync('broken backup');
      final broken = (await service.listBackups()).single;

      await expectLater(service.restore(broken), throwsA(isA<DatabaseCorruptedException>()));

      expect(dbFile.readAsBytesSync(), before);
    });
  });
}
