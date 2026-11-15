import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/database/exceptions.dart';
import 'package:attendly/features/daily_log/providers/daily_log_providers.dart';
import 'package:attendly/features/directory/providers/directory_providers.dart';
import 'package:attendly/features/weekly_report/providers/weekly_report_providers.dart';
import 'package:attendly/features/yearly_report/providers/yearly_report_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// While a database is switched or closed, [appDatabaseProvider] fails with a
/// [DatabaseNotReadyException]. The pages must recognize this, because they
/// send every other error to the error screen. Riverpod wraps the exception
/// for every reader, so the pages use [isDatabaseNotReady].
void main() {
  group('isDatabaseNotReady', () {
    test('is true for the exception itself', () {
      expect(isDatabaseNotReady(const DatabaseNotReadyException()), isTrue);
    });

    test('is false for other errors and for no error', () {
      expect(isDatabaseNotReady(Exception('disk failure')), isFalse);
      expect(isDatabaseNotReady(StateError('bad state')), isFalse);
      expect(isDatabaseNotReady(null), isFalse);
    });
  });

  group('while no database is open', () {
    late ProviderContainer container;

    /// The error that reading [provider] throws.
    Object readError(ProviderListenable<Object?> provider) {
      try {
        container.read(provider);
      } catch (error) {
        return error;
      }
      fail('expected the provider to fail');
    }

    /// The error that [provider] reports to a page that watches it.
    Future<Object?> watchedError(ProviderListenable<AsyncValue<Object?>> provider) async {
      final subscription = container.listen(provider, (_, _) {}, onError: (_, _) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      return container.read(provider).error;
    }

    setUp(() {
      // No override: the database provider starts without an open database.
      container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);
    });

    test('Riverpod wraps the exception when the database is read', () {
      final error = readError(appDatabaseProvider);

      expect(error, isA<ProviderException>());
      expect(error, isNot(isA<DatabaseNotReadyException>()));
      expect(isDatabaseNotReady(error), isTrue);
    });

    test('a repository fails with an error that isDatabaseNotReady recognizes', () {
      expect(isDatabaseNotReady(readError(directoryRepositoryProvider)), isTrue);
      expect(isDatabaseNotReady(readError(dailyRepositoryProvider)), isTrue);
      expect(isDatabaseNotReady(readError(weeklyRepositoryProvider)), isTrue);
      expect(isDatabaseNotReady(readError(yearlyRepositoryProvider)), isTrue);
    });

    test('the streams of the pages fail with an error that isDatabaseNotReady recognizes', () async {
      final monday = DateTime(2026, 3, 2);

      expect(isDatabaseNotReady(await watchedError(directoryStreamProvider)), isTrue);
      expect(isDatabaseNotReady(await watchedError(filteredDirectoryProvider)), isTrue);
      expect(isDatabaseNotReady(await watchedError(dailyRawLogsProvider)), isTrue);
      expect(isDatabaseNotReady(await watchedError(dailyFilteredLogsProvider)), isTrue);
      expect(isDatabaseNotReady(await watchedError(weeklyReportProvider(monday))), isTrue);
      expect(isDatabaseNotReady(await watchedError(allWeeksProvider)), isTrue);
      expect(isDatabaseNotReady(await watchedError(yearlyStatsProvider)), isTrue);
      expect(isDatabaseNotReady(await watchedError(databaseSchemaVersionProvider)), isTrue);
    });
  });
}
