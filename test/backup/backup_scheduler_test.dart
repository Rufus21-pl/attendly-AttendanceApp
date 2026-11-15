import 'dart:async';

import 'package:attendly/data/backup/backup_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the backup runs: after the writes stop, one at a time, and at once on flush.
void main() {
  late StreamController<void> writes;
  late int backups;

  /// Lets the scheduler receive the writes that were added.
  Future<void> deliver() => Future<void>.delayed(Duration.zero);

  setUp(() {
    writes = StreamController<void>();
    backups = 0;
    addTearDown(writes.close);
  });

  BackupScheduler scheduler({
    Duration delay = const Duration(minutes: 1),
    Future<void> Function()? backup,
  }) {
    final result = BackupScheduler(
      writes: writes.stream,
      backup: backup ?? () async => backups++,
      delay: delay,
    )..start();
    addTearDown(result.close);
    return result;
  }

  test('many writes in a row give one backup after the delay', () async {
    scheduler(delay: const Duration(milliseconds: 40));

    for (var i = 0; i < 5; i++) {
      writes.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(backups, 0, reason: 'the delay starts again with every write');

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(backups, 1);
  });

  test('without a write no backup runs', () async {
    final s = scheduler();

    await s.flush();

    expect(backups, 0);
  });

  test('flush writes a waiting backup at once', () async {
    final s = scheduler();
    writes.add(null);
    await deliver();

    await s.flush();

    expect(backups, 1);
  });

  test('flush writes the waiting backup only once', () async {
    final s = scheduler();
    writes.add(null);
    await deliver();

    await s.flush();
    await s.flush();

    expect(backups, 1);
  });

  test('a write during a backup gives one more backup, never two at a time', () async {
    final gate = Completer<void>();
    var running = 0;
    var mostAtOnce = 0;
    final s = scheduler(backup: () async {
      running++;
      if (running > mostAtOnce) mostAtOnce = running;
      if (backups == 0) await gate.future;
      backups++;
      running--;
    });

    s.requestBackup();
    final first = s.flush();
    await deliver();
    s.requestBackup();
    final second = s.flush();
    gate.complete();
    await Future.wait([first, second]);

    expect(backups, 2);
    expect(mostAtOnce, 1);
  });

  test('a failed backup is not thrown and later backups still run', () async {
    var attempts = 0;
    final s = scheduler(backup: () async {
      attempts++;
      if (attempts == 1) throw Exception('disk full');
      backups++;
    });

    s.requestBackup();
    await s.flush();
    expect(backups, 0);

    s.requestBackup();
    await s.flush();
    expect(backups, 1);
  });

  test('close writes the waiting backup and ignores later writes', () async {
    final s = scheduler();
    writes.add(null);
    await deliver();

    await s.close();
    expect(backups, 1);

    s.requestBackup();
    await s.flush();
    expect(backups, 1);
  });
}
