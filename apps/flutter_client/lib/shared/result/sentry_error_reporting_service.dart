import "dart:async";

import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:sentry_flutter/sentry_flutter.dart";

final class SentryErrorReportingService implements ErrorReportingService {
  const SentryErrorReportingService();

  @override
  void report({
    required Exception error,
    required StackTrace stackTrace,
  }) {
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }
}
