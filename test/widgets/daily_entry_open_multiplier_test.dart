import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/tables/enums/category.dart';
import 'package:attendly/features/daily_log/pages/daily_entry_form_page.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// The add form offers the multiplier for the "open" category and adds
/// several "open" entries for one person on one day.
void main() {
  final l10n = AppLocalizationsEn();
  final monday = DateTime(2026, 3, 2);
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// Opens the add form for [personId] on [monday] and selects "open".
  Future<void> openFormWithOpen(WidgetTester tester, int personId) async {
    // Tall enough to show the whole form without scrolling.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    await pumpWithDatabase(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<Object?>(
            MaterialPageRoute(
              builder: (_) => DailyEntryFormPage(
                mode: DailyEntryFormMode.add,
                initialDate: monday,
                preselectedPersons: [(id: personId, name: 'Anonymous')],
              ),
            ),
          ),
          child: const Text('open form'),
        ),
      ),
      db: db,
    );
    await tester.tap(find.text('open form'));
    await settleStreams(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, l10n.open));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text(l10n.submit));
    await settleStreams(tester);
    await tester.pumpAndSettle();
  }

  Future<List<DailyEntryData>> entriesOf(WidgetTester tester, int personId) async =>
      (await tester.runAsync(() => db.readDao.getDailyEntriesByPersonId(personId)))!;

  testWidgets('the multiplier is offered for the category open', (tester) async {
    await openFormWithOpen(tester, 1);

    expect(find.text(l10n.numberOfEntries), findsOneWidget);
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('open with the multiplier 3 adds 3 entries for one person', (tester) async {
    final anonymous = (await tester.runAsync(() => addTestPerson(db, 'Anonymous')))!;
    await openFormWithOpen(tester, anonymous);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);

    await submit(tester);
    expect(find.text(l10n.personsAddedSuccessfully(1)), findsOneWidget);

    final entries = await entriesOf(tester, anonymous);
    expect(entries.map((e) => (e.date, e.category)), List.filled(3, (monday, Category.open)));
    await unmount(tester);
  });

  testWidgets('a person with an open entry gets a second one on the same day', (tester) async {
    final anonymous = (await tester.runAsync(() async {
      final id = await addTestPerson(db, 'Anonymous');
      await addTestEntry(db, personId: id, date: monday, category: Category.open);
      return id;
    }))!;
    await openFormWithOpen(tester, anonymous);

    await submit(tester);
    expect(find.text(l10n.personsAddedSuccessfully(1)), findsOneWidget);
    expect(find.text(l10n.personAlreadyInCategoryOpen('Anonymous')), findsNothing);

    final entries = await entriesOf(tester, anonymous);
    expect(entries.map((e) => (e.date, e.category)), List.filled(2, (monday, Category.open)));
    await unmount(tester);
  });
}
