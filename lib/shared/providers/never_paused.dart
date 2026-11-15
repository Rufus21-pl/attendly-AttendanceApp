import 'dart:async';

extension NeverPaused<T> on Stream<T> {
  /// This stream, but a pause of the listener never reaches it.
  ///
  /// Use it for every database stream that a StreamProvider returns.
  ///
  /// Riverpod pauses the stream of a StreamProvider while nobody watches the
  /// provider or its page is hidden. Drift, when it closes a database, waits
  /// until every query stream has taken its "done" event, and a paused stream
  /// never takes it. A database switch then waits forever on the loading
  /// screen.
  ///
  /// With this, only the returned copy is paused. While it is paused, only
  /// the newest event is kept and sent on resume: a database stream always
  /// sends its complete result, so older events are out of date.
  Stream<T> neverPaused() {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    T? waiting;
    var hasWaiting = false;

    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          (event) {
            if (controller.isPaused) {
              waiting = event;
              hasWaiting = true;
            } else {
              controller.add(event);
            }
          },
          onError: controller.addError,
          // Not awaited: the copy can still be paused.
          onDone: () => unawaited(controller.close()),
        );
      },
      onResume: () {
        if (!hasWaiting) return;
        final event = waiting as T;
        waiting = null;
        hasWaiting = false;
        controller.add(event);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
