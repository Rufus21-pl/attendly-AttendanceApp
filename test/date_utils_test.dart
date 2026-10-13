import 'package:attendly/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isoCalendarWeek', () {
    test('a week in the middle of the year', () {
      expect(isoCalendarWeek(DateTime(2026, 10, 12)), (week: 42, year: 2026));
    });

    test('the days around new year belong to the week of the first Thursday', () {
      // Thursday 1.1.2026 starts week 1, so the Monday before is in it too.
      expect(isoCalendarWeek(DateTime(2025, 12, 29)), (week: 1, year: 2026));
      expect(isoCalendarWeek(DateTime(2026, 1, 1)), (week: 1, year: 2026));
      // 1.1.2021 was a Friday: that week still belongs to 2020.
      expect(isoCalendarWeek(DateTime(2021, 1, 1)), (week: 53, year: 2020));
      expect(isoCalendarWeek(DateTime(2021, 1, 4)), (week: 1, year: 2021));
    });

    test('the daylight saving change does not shift the week', () {
      // Clocks change on Sunday 29.3.2026; Monday 30.3. starts week 14.
      expect(isoCalendarWeek(DateTime(2026, 3, 30)), (week: 14, year: 2026));
      expect(isoCalendarWeek(DateTime(2026, 3, 29)), (week: 13, year: 2026));
    });
  });
}
