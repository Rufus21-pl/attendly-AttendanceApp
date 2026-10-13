import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/features/weekly_report/pages/week_list_page.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final monday = DateTime(2026, 3, 2);
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('the switch shows and toggles whether a week is counted', (tester) async {
    await tester.runAsync(() => db.into(db.weeklyEntry).insert(WeeklyEntryCompanion.insert(
          weekDate: monday, under_10: 1, age_10_13: 0, age_14_17: 0, age_18_24: 0, over_24: 0,
          allM: 1, allF: 0, allD: 0, openMale: 1, openFemale: 0, openDiverse: 0,
          offersMale: 0, offersFemale: 0, offersDiverse: 0, migrationMale: 0,
          migrationFemale: 0, migrationDiverse: 0, countable: true,
        )));

    await pumpWithDatabase(tester, WeekListPage(currentWeekDate: monday), db: db);

    expect(find.text('02.03.2026 - 06.03.2026'), findsOneWidget);
    expect(find.text(l10n.selectedWeek), findsOneWidget);
    expect(find.text(l10n.countedInYearReport), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await settleStreams(tester);

    expect(find.text(l10n.notCountedInYearReport), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    final week = (await tester.runAsync(() => db.select(db.weeklyEntry).getSingle()))!;
    expect(week.countable, isFalse);
    await unmount(tester);
  });
}
