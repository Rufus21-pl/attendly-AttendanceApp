import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A value that pages read and set directly, such as the selected date, a
/// search text or the visible tab.
///
/// Declare it with a [NotifierProvider]:
/// ```dart
/// final searchProvider = NotifierProvider.autoDispose<ValueState<String>, String>(
///   () => ValueState((ref) => ''),
/// );
/// ```
/// Read the value with `ref.watch(searchProvider)` and change it with
/// `ref.read(searchProvider.notifier).set('anna')`.
class ValueState<T> extends Notifier<T> {
  /// [initial] gives the start value. It can watch other providers; the
  /// value then starts again from [initial] when one of them changes.
  ValueState(this._initial);

  final T Function(Ref ref) _initial;

  @override
  T build() => _initial(ref);

  /// The current value, for code that holds this notifier.
  T get value => state;

  /// Replaces the value.
  void set(T value) => state = value;

  /// Replaces the value with the result of [change] on the current value.
  void update(T Function(T current) change) => state = change(state);
}
