import 'package:attendly/features/weekly_report/providers/weekly_report_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the selected week after the weekly tab is left', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final monday = DateTime(2026, 3, 2);

    // The open weekly tab watches the week; leaving the tab drops the listener.
    final subscription = container.listen(selectedWeekProvider, (_, _) {});
    container.read(selectedWeekProvider.notifier).state = monday;
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(selectedWeekProvider), monday);
  });
}
