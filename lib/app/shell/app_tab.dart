import 'package:attendly/shared/providers/value_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs of the app shell, in drawer/rail order.
enum AppTab { directory, dailyLog, weeklyReport, yearlyReport }

/// The visible tab. Disposed with the shell, so after a database switch the
/// app starts on the directory again.
final selectedTabProvider = NotifierProvider.autoDispose<ValueState<AppTab>, AppTab>(
  () => ValueState((ref) => AppTab.directory),
);
