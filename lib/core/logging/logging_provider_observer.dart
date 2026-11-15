import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/core/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logs every provider that throws or whose Future/Stream emits an error,
/// including the stack trace, so failing streams can be traced back.
final class LoggingProviderObserver extends ProviderObserver {
  const LoggingProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final provider = context.provider;
    final name = provider.name ?? provider.runtimeType.toString();

    // Expected while the database is being switched or closed.
    if (isDatabaseNotReady(error)) {
      AppLogger.d('Provider', '$name: database not ready');
      return;
    }

    AppLogger.e('Provider', '$name failed', error, stackTrace);
  }
}
