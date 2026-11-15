import 'dart:async';

import 'package:attendly/core/logging/app_logger.dart';

/// Decides when the backup of the open database runs.
///
/// Every write asks for a backup. The backup runs [delay] after the last
/// write, so many writes in a row give one backup, and only one backup runs
/// at a time. A failed backup is logged and never reaches the pages.
class BackupScheduler {
  static const String _tag = 'Backup';

  /// Long enough to join the writes of one action (a form with many people),
  /// short enough that little is lost when the app is closed.
  static const Duration defaultDelay = Duration(seconds: 3);

  /// [writes] emits whenever the database changed. [backup] writes the copy.
  BackupScheduler({
    required Stream<void> writes,
    required Future<void> Function() backup,
    this.delay = defaultDelay,
  })  : _writes = writes,
        _backup = backup;

  final Duration delay;
  final Stream<void> _writes;
  final Future<void> Function() _backup;

  StreamSubscription<void>? _subscription;
  Timer? _timer;
  Future<void>? _running;
  bool _pending = false;
  bool _closed = false;

  void start() {
    _subscription ??= _writes.listen((_) => requestBackup());
  }

  /// Asks for a backup [delay] from now. An earlier request waits again.
  void requestBackup() {
    if (_closed) return;
    _pending = true;
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  /// Writes a requested backup now and waits until no backup is running.
  /// Does nothing when no backup is requested.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _run();
  }

  /// Writes a requested backup, then stops reacting to writes.
  Future<void> close() async {
    if (_closed) return;
    await flush();
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _run() async {
    final running = _running;
    if (running != null) return running;

    final done = Completer<void>();
    _running = done.future;
    try {
      // A write during a backup asks for one more.
      while (_pending) {
        _pending = false;
        await _backup();
      }
    } catch (e, stackTrace) {
      AppLogger.e(_tag, 'The backup failed', e, stackTrace);
    } finally {
      _running = null;
      done.complete();
    }
  }
}
