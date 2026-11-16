import 'dart:io';

import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/features/settings/pages/settings_page.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:attendly/l10n/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../fakes/fake_database_manager.dart';
import '../helpers/pump_app.dart';

BackupInfo _backup(String dbFileName, BackupKind kind, DateTime modified) => BackupInfo(
      file: File('/storage/emulated/0/Documents/AttendlyDb/backup/$dbFileName.${kind.name}.bak'),
      dbFileName: dbFileName,
      kind: kind,
      modified: modified,
      sizeBytes: 200704,
    );

/// The backup entry in Settings > Data.
void main() {
  final l10n = AppLocalizationsEn();
  late FakeDatabaseManager manager;
  late ProviderContainer container;

  setUp(() {
    manager = FakeDatabaseManager();
    container = ProviderContainer(
      // Like the app: a failed provider is not started again by itself.
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWith(() => DatabaseNotifier(manager)),
      ],
    );
    PackageInfo.setMockInitialValues(
      appName: 'attendly',
      packageName: 'attendly',
      version: '1.2.3',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() async {
    container.dispose();
    await manager.closeDatabase();
  });

  /// Pumps the settings page; with [openDatabase] the main database is open.
  Future<void> pumpSettings(WidgetTester tester, {bool openDatabase = true}) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    if (openDatabase) {
      await tester.runAsync(() => container.read(databaseProvider.notifier).openDatabase());
    }

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: SettingsPage(),
      ),
    ));
    await settleStreams(tester);
  }

  testWidgets('shows the time of the latest backup of the open database', (tester) async {
    manager.backups = [
      _backup('db_2025.db', BackupKind.latest, DateTime(2026, 11, 16, 9, 0)),
      _backup('db_2026.db', BackupKind.latest, DateTime(2026, 11, 15, 23, 56)),
      _backup('db_2026.db', BackupKind.previousDay, DateTime(2026, 11, 14, 18, 5)),
    ];

    await pumpSettings(tester);

    expect(find.text(l10n.databaseBackup), findsOneWidget);
    expect(find.text(l10n.lastBackupAt('15.11.2026 23:56')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('says so when the database has no backup yet', (tester) async {
    await pumpSettings(tester);

    expect(find.text(l10n.noBackupYet), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a tap writes a backup and confirms it', (tester) async {
    await pumpSettings(tester);
    // The backup that the manager writes when asked.
    manager.backups = [_backup('db_2026.db', BackupKind.latest, DateTime.now())];

    await tester.tap(find.text(l10n.databaseBackup));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(manager.manualBackups, 1);
    expect(find.text(l10n.backupWritten), findsOneWidget);
    expect(find.text(l10n.noBackupYet), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('a tap reports when no new backup was written', (tester) async {
    // A damaged database gets no backup: the old file stays. Its time is
    // relative to the clock of the machine, so the test passes at any time.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    manager.backups = [_backup('db_2026.db', BackupKind.latest, yesterday)];
    await pumpSettings(tester);

    await tester.tap(find.text(l10n.databaseBackup));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(manager.manualBackups, 1);
    expect(find.text(l10n.backupFailed), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('without an open database a tap shows an error and writes nothing', (tester) async {
    await pumpSettings(tester, openDatabase: false);

    await tester.tap(find.text(l10n.databaseBackup));
    await tester.pumpAndSettle();

    expect(manager.manualBackups, 0);
    expect(find.text(l10n.databaseNotConnected), findsOneWidget);
    await unmount(tester);
  });
}
