import 'package:flutter_riverpod/legacy.dart';

/// The tabs of the app shell, in drawer/rail order.
enum AppTab { directory, dailyLog, weeklyReport, yearlyReport }

/// The visible tab. Disposed with the shell, so after a database switch the
/// app starts on the directory again.
final selectedTabProvider = StateProvider.autoDispose<AppTab>((ref) => AppTab.directory);
