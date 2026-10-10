import 'package:attendly/app/app.dart';
import 'package:attendly/core/permissions/storage_permission_service.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/settings/settings_service.dart';
import 'package:attendly/features/settings/providers/settings_notifier.dart';
import 'package:attendly/l10n/app_de.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_database_manager.dart';
import '../fakes/fake_storage_permission_service.dart';
import '../helpers/pump_app.dart';

class _GermanSettingsService extends SettingsService {
  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.light;

  @override
  Future<Locale> getLocale() async => const Locale('de');
}

void main() {
  final de = AppLocalizationsDe();

  testWidgets('the year-change question uses the language from settings.json',
      (tester) async {
    final manager = FakeDatabaseManager()..rolloverNeeded = true;
    final permission = FakeStoragePermissionService()
      ..current = PermissionState.denied
      ..afterRequest = PermissionState.granted;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => DatabaseNotifier(manager)),
        storagePermissionServiceProvider.overrideWithValue(permission),
        settingsProvider.overrideWith((ref) => SettingsNotifier(_GermanSettingsService())),
      ],
      child: const AttendlyApp(),
    ));
    await settleStreams(tester);

    // Fresh install: settings.json can only be read after the permission.
    await tester.tap(find.byType(ElevatedButton));
    await settleStreams(tester);

    expect(find.text(de.yearChangeDetected), findsOneWidget);
    expect(find.text(de.createNew), findsOneWidget);

    await unmount(tester);
    await manager.closeDatabase();
  });
}
