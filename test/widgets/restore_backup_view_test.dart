import 'dart:io';

import 'package:attendly/app/startup/startup_gate.dart';
import 'package:attendly/core/permissions/storage_permission_service.dart';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/data/settings/settings_service.dart';
import 'package:attendly/features/settings/providers/settings_notifier.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:attendly/l10n/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_database_manager.dart';
import '../fakes/fake_storage_permission_service.dart';
import '../helpers/pump_app.dart';

class _FakeSettingsService extends SettingsService {
  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.light;

  @override
  Future<Locale> getLocale() async => const Locale('en');
}

BackupInfo _backup(String dbFileName, BackupKind kind, DateTime modified) => BackupInfo(
      file: File('/storage/emulated/0/Documents/AttendlyDb/backup/$dbFileName.${kind.name}.bak'),
      dbFileName: dbFileName,
      kind: kind,
      modified: modified,
      sizeBytes: 200704,
    );

/// The restore screen and the restore button on the setup screen.
void main() {
  const mainDbPath = '/storage/emulated/0/Documents/AttendlyDb/db_2026.db';
  final l10n = AppLocalizationsEn();
  final latest = _backup('db_2026.db', BackupKind.latest, DateTime(2026, 11, 15, 23, 56));
  final previous = _backup('db_2026.db', BackupKind.previousDay, DateTime(2026, 11, 14, 18, 5));

  late FakeDatabaseManager manager;

  setUp(() {
    manager = FakeDatabaseManager();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'attendly',
      packageName: 'attendly',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
  });

  tearDown(() => manager.closeDatabase());

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(580, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith(() => DatabaseNotifier(manager)),
        storagePermissionServiceProvider.overrideWithValue(FakeStoragePermissionService()),
        settingsProvider.overrideWith(() => SettingsNotifier(_FakeSettingsService())),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: StartupGate(),
      ),
    ));
    await settleStreams(tester);
  }

  /// Taps "Restore backup" and answers the confirm dialog.
  Future<void> restore(WidgetTester tester, {required bool confirm}) async {
    await tester.tap(find.text(l10n.restoreBackup));
    await tester.pumpAndSettle();
    expect(find.text(l10n.confirmRestoreTitle), findsOneWidget);

    final dialog = find.byType(AlertDialog);
    await tester.tap(find.descendant(
      of: dialog,
      matching: find.text(confirm ? l10n.restoreBackup : l10n.cancel),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settleStreams(tester);
  }

  group('a database file that cannot be read', () {
    setUp(() {
      manager
        ..openError = DatabaseCorruptedException(mainDbPath)
        ..backups = [latest, previous];
    });

    testWidgets('shows the backups with kind, time and size', (tester) async {
      await pumpGate(tester);

      expect(find.text(l10n.restoreTitleUnreadable), findsOneWidget);
      expect(find.text(l10n.restoreMessageUnreadable), findsOneWidget);
      expect(find.text('db_2026.db · ${l10n.backupLatest}'), findsOneWidget);
      expect(find.text('15.11.2026 23:56 · 196 KB'), findsOneWidget);
      expect(find.text('db_2026.db · ${l10n.backupPreviousDay}'), findsOneWidget);
      expect(find.text('14.11.2026 18:05 · 196 KB'), findsOneWidget);
      expect(find.text(l10n.showLogs), findsOneWidget);
      // The file is where a new database would be, and it is not open.
      expect(find.text(l10n.createNew), findsNothing);
      expect(find.text(l10n.continueWithDatabase), findsNothing);
      await unmount(tester);
    });

    testWidgets('restores the newest backup after the user confirms', (tester) async {
      await pumpGate(tester);

      await restore(tester, confirm: true);

      expect(manager.restoredBackup, same(latest));
      expect(find.text(l10n.noPersonFound), findsOneWidget, reason: 'the app shows the directory');
      await unmount(tester);
    });

    testWidgets('restores the backup that the user selected', (tester) async {
      await pumpGate(tester);

      await tester.tap(find.text('db_2026.db · ${l10n.backupPreviousDay}'));
      await tester.pump();
      await restore(tester, confirm: true);

      expect(manager.restoredBackup, same(previous));
      await unmount(tester);
    });

    testWidgets('does nothing when the user cancels', (tester) async {
      await pumpGate(tester);

      await restore(tester, confirm: false);

      expect(manager.restoredBackup, isNull);
      expect(find.text(l10n.restoreTitleUnreadable), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows a message when the restore fails', (tester) async {
      manager.restoreError = const FileSystemException('disk full');
      await pumpGate(tester);

      await restore(tester, confirm: true);
      await tester.pumpAndSettle();

      expect(find.text(l10n.restoreFailed), findsOneWidget);
      await unmount(tester);
    });
  });

  group('a database that opens but is damaged', () {
    setUp(() {
      manager
        ..damaged = true
        ..backups = [latest];
    });

    testWidgets('offers to restore or to continue', (tester) async {
      await pumpGate(tester);

      expect(find.text(l10n.restoreTitleDamaged), findsOneWidget);
      expect(find.text(l10n.restoreBackup), findsOneWidget);
      expect(find.text(l10n.continueWithDatabase), findsOneWidget);
      expect(find.text(l10n.createNew), findsNothing);
      await unmount(tester);
    });

    testWidgets('continue opens the app with this database', (tester) async {
      await pumpGate(tester);

      await tester.tap(find.text(l10n.continueWithDatabase));
      await tester.pump();
      await settleStreams(tester);

      expect(find.text(l10n.noPersonFound), findsOneWidget);
      expect(manager.restoredBackup, isNull);
      await unmount(tester);
    });
  });

  group('a main database file that is missing', () {
    testWidgets('offers to restore or to create a new database', (tester) async {
      manager
        ..openError = const DatabaseFileMissingException(mainDbPath)
        ..backups = [latest];
      await pumpGate(tester);

      expect(find.text(l10n.restoreTitleMissing), findsOneWidget);
      expect(find.text(l10n.restoreBackup), findsOneWidget);
      expect(find.text(l10n.createNew), findsOneWidget);
      expect(find.text(l10n.continueWithDatabase), findsNothing);
      await unmount(tester);
    });
  });

  group('first start', () {
    setUp(() => manager.initialSetupNeeded = true);

    testWidgets('without backups the setup screen has no restore button', (tester) async {
      await pumpGate(tester);

      expect(find.text(l10n.createDatabase), findsOneWidget);
      expect(find.text(l10n.restoreFromBackup), findsNothing);
      await unmount(tester);
    });

    testWidgets('with backups the setup screen leads to the restore screen', (tester) async {
      manager.backups = [latest];
      await pumpGate(tester);
      expect(find.text(l10n.createDatabase), findsOneWidget);

      await tester.tap(find.text(l10n.restoreFromBackup));
      await tester.pump();
      await settleStreams(tester);

      expect(find.text(l10n.restoreMessageNoDatabase), findsOneWidget);
      expect(find.text('db_2026.db · ${l10n.backupLatest}'), findsOneWidget);
      expect(find.text(l10n.createDatabase), findsOneWidget);

      await restore(tester, confirm: true);

      expect(manager.restoredBackup, same(latest));
      expect(find.text(l10n.noPersonFound), findsOneWidget);
      await unmount(tester);
    });
  });
}
