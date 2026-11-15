import 'package:attendly/shared/providers/value_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _year = NotifierProvider<ValueState<int>, int>(() => ValueState((ref) => 2026));

/// Starts at the first day of [_year], like the selected date of a database year.
final _date = NotifierProvider<ValueState<DateTime>, DateTime>(
  () => ValueState((ref) => DateTime(ref.watch(_year))),
);

final _search = NotifierProvider.autoDispose<ValueState<String>, String>(
  () => ValueState((ref) => ''),
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts with the initial value', () {
    expect(container.read(_year), 2026);
    expect(container.read(_date), DateTime(2026));
  });

  test('set replaces the value and tells the listeners', () {
    final seen = <int>[];
    container.listen(_year, (_, next) => seen.add(next));

    container.read(_year.notifier).set(2027);

    expect(container.read(_year), 2027);
    expect(container.read(_year.notifier).value, 2027);
    expect(seen, [2027]);
  });

  test('set with the current value tells nobody', () {
    final seen = <int>[];
    container.listen(_year, (_, next) => seen.add(next));

    container.read(_year.notifier).set(2026);

    expect(seen, isEmpty);
  });

  testWidgets('a widget can set the current value again while it is built', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) {
        // Like a page that clears an empty search text in initState.
        ref.read(_search.notifier).set('');
        return Text(ref.watch(_search), textDirection: TextDirection.ltr);
      }),
    ));

    expect(tester.takeException(), isNull);
  });

  test('update changes the value from the current value', () {
    container.read(_year.notifier).update((year) => year + 1);

    expect(container.read(_year), 2027);
  });

  test('the value starts again when a watched provider changes', () {
    container.read(_date.notifier).set(DateTime(2026, 3, 2));
    expect(container.read(_date), DateTime(2026, 3, 2));

    container.read(_year.notifier).set(2025);

    expect(container.read(_date), DateTime(2025));
  });

  test('invalidate returns to the initial value', () {
    container.read(_date.notifier).set(DateTime(2026, 3, 2));

    container.invalidate(_date);

    expect(container.read(_date), DateTime(2026));
  });

  test('an auto-dispose value is forgotten when nobody watches it', () async {
    final subscription = container.listen(_search, (_, _) {});
    container.read(_search.notifier).set('anna');
    expect(container.read(_search), 'anna');

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(_search), '');
  });
}
