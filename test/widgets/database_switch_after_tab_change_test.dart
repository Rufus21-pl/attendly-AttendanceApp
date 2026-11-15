import 'dart:io';

import 'package:attendly/app/shell/app_shell.dart';
import 'package:attendly/app/shell/app_tab.dart';
import 'package:attendly/app/startup/app_startup_notifier.dart';
import 'package:attendly/app/startup/startup_gate.dart';
import 'package:attendly/app/startup/startup_state.dart';
import 'package:attendly/core/permissions/storage_permission_service.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/settings/settings_service.dart';
import 'package:attendly/features/settings/providers/settings_notifier.dart';
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

/// The people list of the directory stays in memory when the user goes to
/// another tab. Nobody watches it then, and Riverpod pauses a stream that
/// nobody watches. Drift waits for every stream when it closes a database,
/// and a paused stream never answers: the database switch stayed on the
/// loading screen.
void main() {
  const otherDatabase = '/storage/emulated/0/Documents/AttendlyDb/db_2025.db';
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

  /// Starts the app on the directory tab with an open database.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(580, 1000);
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
    return ProviderScope.containerOf(tester.element(find.byType(StartupGate)));
  }

  Future<void> switchDatabase(WidgetTester tester, ProviderContainer container) async {
    container.read(appStartupProvider.notifier).openDatabaseFile(File(otherDatabase));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await settleStreams(tester);
  }

  void expectSwitched(ProviderContainer container) {
    final startup = container.read(appStartupProvider);
    expect(startup.isLoading, isFalse, reason: 'closing the old database must not wait forever');
    expect(startup.value, isA<StartupReady>());
    expect(manager.currentDbPath, otherDatabase);
  }

  for (final tab in [AppTab.dailyLog, AppTab.weeklyReport, AppTab.yearlyReport]) {
    testWidgets('a database switch finishes after the directory was left for the ${tab.name} tab',
        (tester) async {
      final container = await pumpApp(tester);

      container.read(selectedTabProvider.notifier).set(tab);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleStreams(tester);

      await switchDatabase(tester, container);

      expectSwitched(container);
      await unmount(tester);
    });
  }

  testWidgets('a database switch finishes on the directory tab', (tester) async {
    final container = await pumpApp(tester);

    await switchDatabase(tester, container);

    expectSwitched(container);
    await unmount(tester);
  });

  testWidgets('a database switch finishes from a page that covers the shell', (tester) async {
    final container = await pumpApp(tester);
    container.read(selectedTabProvider.notifier).set(AppTab.dailyLog);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Like the database picker: once its animation ends, the shell is hidden.
    Navigator.of(tester.element(find.byType(AppShell))).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('page on top'))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settleStreams(tester);
    expect(find.text('page on top'), findsOneWidget);

    await switchDatabase(tester, container);

    expectSwitched(container);
    expect(find.text('page on top'), findsNothing);
    await unmount(tester);
  });
}
