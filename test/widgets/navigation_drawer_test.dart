import 'package:attendly/app/shell/app_shell.dart';
import 'package:attendly/app/shell/app_tab.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(580, 1000);
    addTearDown(tester.view.reset);

    await pumpWithDatabase(
      tester,
      const AppShell(),
      db: db,
      overrides: [selectedTabProvider.overrideWith((ref) => AppTab.directory)],
    );
  }

  testWidgets('the drawer header shows the database kind', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text(l10n.attendly), findsOneWidget);
    expect(find.text(l10n.mainDatabase), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the drawer shows the new-year banner when a new year is available',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text(l10n.newYearAvailable), findsNothing);

    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(databaseProvider.notifier)
        .setShowNewYearBanner(true);
    // The banner pulses forever, so pump fixed durations instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.newYearAvailable), findsOneWidget);
    expect(find.text(l10n.newYearBannerHint), findsOneWidget);
    await unmount(tester);
  });
}
