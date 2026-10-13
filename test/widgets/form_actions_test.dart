import 'package:attendly/l10n/app_de.dart';
import 'package:attendly/l10n/app_localizations_delegate.dart';
import 'package:attendly/shared/widgets/form_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsDe();

  Future<void> pumpActions(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de')],
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FormActions(onReset: () {}, onSubmit: () {}, submitLabel: l10n.submit),
        ),
      ),
    ));
  }

  /// Height of one line of the reset label, so a wrapped label is noticed.
  double lineHeight(WidgetTester tester) =>
      tester.getSize(find.text(l10n.submit)).height;

  testWidgets('on a narrow phone the buttons are stacked and "Zurücksetzen" stays on one line',
      (tester) async {
    await pumpActions(tester, 360);

    final reset = tester.getRect(find.text(l10n.reset));
    final submit = tester.getRect(find.text(l10n.submit));
    expect(reset.bottom, lessThan(submit.top));
    expect(reset.height, closeTo(lineHeight(tester), 1));
  });

  testWidgets('with enough room the buttons are side by side', (tester) async {
    await pumpActions(tester, 800);

    final reset = tester.getRect(find.text(l10n.reset));
    final submit = tester.getRect(find.text(l10n.submit));
    expect(reset.center.dy, closeTo(submit.center.dy, 1));
    expect(reset.right, lessThan(submit.left));
  });
}
