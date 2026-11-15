import 'package:attendly/app/shell/app_shell.dart';
import 'package:attendly/app/shell/app_tab.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/features/weekly_report/pages/week_list_page.dart';
import 'package:attendly/l10n/app_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// While a database is switched, the pages are on screen for a moment without
/// an open database. They must wait, and must not send this state to the
/// error screen.
void main() {
  /// Pumps [child] without an open database, like during a database switch.
  Future<ProviderContainer> pumpWithoutDatabase(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(580, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: child,
      ),
    ));
    await settleStreams(tester);
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  for (final tab in AppTab.values) {
    testWidgets('the ${tab.name} tab waits and reports no database error', (tester) async {
      final container = await pumpWithoutDatabase(
        tester,
        const AppShell(),
        overrides: [selectedTabProvider.overrideWith((ref) => tab)],
      );

      expect(container.read(databaseProvider).dbError, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await unmount(tester);
    });
  }

  group('when the open database is closed', () {
    late AppDatabase db;

    /// False after the database was closed, like at the start of a switch.
    final databaseOpen = StateProvider<bool>((ref) => true);

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    final pages = <String, Widget>{
      for (final tab in AppTab.values) 'the ${tab.name} tab': const AppShell(),
      'the week list': WeekListPage(currentWeekDate: DateTime(2026, 3, 2)),
    };

    for (final MapEntry(key: name, value: page) in pages.entries) {
      testWidgets('$name reports no database error', (tester) async {
        final container = await pumpWithoutDatabase(
          tester,
          page,
          overrides: [
            appDatabaseProvider.overrideWith((ref) {
              if (!ref.watch(databaseOpen)) throw const DatabaseNotReadyException();
              return db;
            }),
            for (final tab in AppTab.values)
              if (name == 'the ${tab.name} tab') selectedTabProvider.overrideWith((ref) => tab),
          ],
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        container.read(databaseOpen.notifier).state = false;
        await settleStreams(tester);

        expect(container.read(databaseProvider).dbError, isNull);
        await unmount(tester);
      });
    }
  });

  testWidgets('the week list waits and reports no database error', (tester) async {
    final container = await pumpWithoutDatabase(
      tester,
      WeekListPage(currentWeekDate: DateTime(2026, 3, 2)),
    );

    expect(container.read(databaseProvider).dbError, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await unmount(tester);
  });
}
