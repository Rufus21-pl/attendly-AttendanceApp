import 'package:attendly/app/startup/startup_gate.dart';
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

/// Android can stop the app in the background at any time, so a backup that
/// waits for its delay is written when the app leaves the foreground.
void main() {
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

  testWidgets('the waiting backup is written when the app goes to the background', (tester) async {
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
    expect(manager.backupFlushes, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(manager.backupFlushes, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleStreams(tester);
    expect(manager.backupFlushes, 1);

    await unmount(tester);
  });
}
