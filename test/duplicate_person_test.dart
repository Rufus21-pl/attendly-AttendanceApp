import 'dart:io';

import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/tables/enums/gender.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DirectoryPeopleCompanion _person(String name) => DirectoryPeopleCompanion.insert(
      name: name,
      birthday: DateTime(2015, 1, 1),
      gender: Gender.f,
      migration: false,
    );

void main() {
  group('in memory', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.testInstance());
    tearDown(() => db.close());

    test('isPersonNameTaken ignores upper and lower case, like the UNIQUE constraint', () async {
      await db.insertDao.insertDirPerson(_person('Anna'));

      expect(await db.readDao.isPersonNameTaken('Anna'), isTrue);
      expect(await db.readDao.isPersonNameTaken('anna'), isTrue);
      expect(await db.readDao.isPersonNameTaken('Annika'), isFalse);
    });

    test('isPersonNameTaken does not count the person being edited', () async {
      await db.insertDao.insertDirPerson(_person('Anna'));
      final anna = (await db.readDao.findPeopleByName('Anna')).single;

      expect(await db.readDao.isPersonNameTaken('anna', exceptId: anna.id), isFalse);
    });

    test('insertDirPerson rejects a name that differs only in case', () async {
      await db.insertDao.insertDirPerson(_person('Anna'));

      await expectLater(
        db.insertDao.insertDirPerson(_person('anna')),
        throwsA(isA<DuplicatePersonException>()),
      );
    });
  });

  // The app opens its database in a background isolate, where SQLite errors
  // arrive wrapped. This is the setup the duplicate check failed in.
  test('insertDirPerson reports a duplicate with a background database', () async {
    final dir = await Directory.systemTemp.createTemp('attendly_duplicate_');
    final db = AppDatabase(NativeDatabase.createInBackground(File('${dir.path}/test.db')));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    await db.insertDao.insertDirPerson(_person('Anna'));

    await expectLater(
      db.insertDao.insertDirPerson(_person('Anna')),
      throwsA(isA<DuplicatePersonException>()),
    );
  });
}
