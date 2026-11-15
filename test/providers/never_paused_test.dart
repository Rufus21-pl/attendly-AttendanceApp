import 'dart:async';

import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/shared/providers/never_paused.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  /// Lets the streams deliver what was added.
  Future<void> deliver() => Future<void>.delayed(Duration.zero);

  group('neverPaused', () {
    late StreamController<int> source;
    late bool sourcePaused;

    setUp(() {
      sourcePaused = false;
      source = StreamController<int>(
        onPause: () => sourcePaused = true,
        onResume: () => sourcePaused = false,
      );
    });

    test('passes events and errors on', () async {
      final events = <Object>[];
      source.stream.neverPaused().listen(events.add, onError: (Object e) => events.add('error: $e'));

      source.add(1);
      source.addError('broken');
      source.add(2);
      await deliver();

      expect(events, [1, 'error: broken', 2]);
    });

    test('a pause of the listener does not pause the source', () async {
      final subscription = source.stream.neverPaused().listen((_) {});
      await deliver();

      subscription.pause();
      source.add(1);
      await deliver();

      expect(sourcePaused, isFalse);
      await subscription.cancel();
    });

    test('after a pause only the newest event arrives', () async {
      final events = <int>[];
      final subscription = source.stream.neverPaused().listen(events.add);
      source.add(1);
      await deliver();

      subscription.pause();
      source.add(2);
      source.add(3);
      await deliver();
      expect(events, [1]);

      subscription.resume();
      await deliver();
      expect(events, [1, 3]);

      source.add(4);
      await deliver();
      expect(events, [1, 3, 4]);
      await subscription.cancel();
    });

    test('the source is not listened to before the copy is, and is cancelled with it', () async {
      final copy = source.stream.neverPaused();
      expect(source.hasListener, isFalse);

      final subscription = copy.listen((_) {});
      expect(source.hasListener, isTrue);

      await subscription.cancel();
      expect(source.hasListener, isFalse);
    });

    test('the copy ends when the source ends', () async {
      var done = false;
      source.stream.neverPaused().listen((_) {}, onDone: () => done = true);

      await source.close();
      await deliver();

      expect(done, isTrue);
    });

    test('the source can end while the listener is paused', () async {
      final subscription = source.stream.neverPaused().listen((_) {});
      await deliver();
      subscription.pause();

      // Completes only when the source's listener took the done event.
      await source.close().timeout(const Duration(seconds: 2));

      await subscription.cancel();
    });
  });

  group('closing a database', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());

    test('finishes while a listener of a people stream is paused', () async {
      final subscription = db.readDao.watchAllPerson(true).neverPaused().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      subscription.pause();

      await db.close().timeout(const Duration(seconds: 5));

      await subscription.cancel();
    });
  });
}
