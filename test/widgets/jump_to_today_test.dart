import 'package:attendly/app/shell/app_shell.dart';
import 'package:attendly/app/shell/app_tab.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpShell(WidgetTester tester, AppTab tab) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(580, 1000);
    addTearDown(tester.view.reset);

    await pumpWithDatabase(
      tester,
      const AppShell(),
      db: db,
      overrides: [selectedTabProvider.overrideWith((ref) => tab)],
    );
  }

  testWidgets('the daily log jump button appears away from today and returns to it',
      (tester) async {
    await pumpShell(tester, AppTab.dailyLog);
    final jumpButton = find.byTooltip(l10n.jumpToToday);
    expect(jumpButton, findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_sharp));
    await tester.pumpAndSettle();
    expect(jumpButton, findsOneWidget);

    await tester.tap(jumpButton);
    await tester.pumpAndSettle();
    final today = DateTime.now();
    expect(find.text('${today.day}.${today.month}.${today.year}'), findsOneWidget);
    expect(jumpButton, findsNothing);
    await unmount(tester);
  });

  testWidgets('the weekly report jump button returns to the current week', (tester) async {
    await pumpShell(tester, AppTab.weeklyReport);
    final jumpButton = find.byTooltip(l10n.jumpToCurrentWeek);
    final weekText = find.textContaining(' - ');
    final currentWeek = tester.widget<Text>(weekText).data;
    expect(jumpButton, findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_sharp));
    await tester.pumpAndSettle();
    expect(jumpButton, findsOneWidget);
    expect(tester.widget<Text>(weekText).data, isNot(currentWeek));

    await tester.tap(jumpButton);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(weekText).data, currentWeek);
    expect(jumpButton, findsNothing);
    await unmount(tester);
  });
}
