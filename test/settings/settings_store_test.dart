import 'dart:convert';
import 'dart:io';

import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/data/settings/settings_store.dart';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// [SettingsStore] against a real settings.json in a temporary directory.
void main() {
  late Directory dir;

  final currentYear = getCurrentYearAsInt();

  File settingsFile() => File(p.join(dir.path, SettingsStore.fileName));

  Map<String, dynamic> readFile() =>
      jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;

  Map<String, dynamic> defaults() => {
        'file_path': p.join(dir.path, 'db_$currentYear.db'),
        'current_year': '$currentYear',
        'theme': 'light',
        'language': 'en',
      };

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attendly_settings_test_');
    StorageManager.directoryOverride = dir;
  });

  tearDown(() {
    StorageManager.directoryOverride = null;
    dir.deleteSync(recursive: true);
  });

  group('load', () {
    test('creates settings.json with the defaults when it is missing', () async {
      final settings = await SettingsStore.load();

      expect(settings, defaults());
      expect(readFile(), defaults());
    });

    test('keeps saved values and fills missing keys with the defaults', () async {
      settingsFile().writeAsStringSync(jsonEncode({'theme': 'dark'}));

      final settings = await SettingsStore.load();

      expect(settings, {...defaults(), 'theme': 'dark'});
      expect(readFile(), {...defaults(), 'theme': 'dark'});
    });

    test('keeps keys it does not know', () async {
      settingsFile().writeAsStringSync(jsonEncode({...defaults(), 'extra': 'value'}));

      final settings = await SettingsStore.load();

      expect(settings!['extra'], 'value');
    });

    test('restores the defaults when settings.json is corrupted', () async {
      settingsFile().writeAsStringSync('{"theme": "dar');

      final settings = await SettingsStore.load();

      expect(settings, defaults());
      expect(readFile(), defaults());
    });

    test('restores the defaults when settings.json is empty', () async {
      settingsFile().writeAsStringSync('');

      expect(await SettingsStore.load(), defaults());
    });
  });

  group('update', () {
    test('changes the given keys and keeps the other keys', () async {
      await SettingsStore.load();

      final saved = await SettingsStore.update({'theme': 'dark'});

      expect(saved, isTrue);
      expect(readFile(), {...defaults(), 'theme': 'dark'});
    });

    test('does not lose a change when two updates run at the same time', () async {
      await Future.wait([
        SettingsStore.update({'theme': 'dark'}),
        SettingsStore.update({'language': 'de'}),
      ]);

      expect(readFile(), {...defaults(), 'theme': 'dark', 'language': 'de'});
    });
  });
}
