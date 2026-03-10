typedef ErrorIgnoreCallback = bool Function(Exception error);

abstract interface class ErrorReportingService {
  void report({
    required Exception error,
    required StackTrace stackTrace,
  });
}

final class NoopErrorReportingService implements ErrorReportingService {
  const NoopErrorReportingService();

  @override
  void report({
    required Exception error,
    required StackTrace stackTrace,
  }) {}
}

final class FilteredErrorReportingService implements ErrorReportingService {
  const FilteredErrorReportingService({
    required ErrorReportingService delegate,
    List<ErrorIgnoreCallback> ignoreCallbacks = const <ErrorIgnoreCallback>[],
  })  : _delegate = delegate,
        _ignoreCallbacks = ignoreCallbacks;

  final ErrorReportingService _delegate;
  final List<ErrorIgnoreCallback> _ignoreCallbacks;

  @override
  void report({
    required Exception error,
    required StackTrace stackTrace,
  }) {
    final shouldIgnore = _ignoreCallbacks.any((callback) => callback(error));
    if (shouldIgnore) {
      return;
    }

    _delegate.report(error: error, stackTrace: stackTrace);
  }
}

abstract final class ResultErrorReporting {
  static ErrorReportingService _service = const NoopErrorReportingService();

  static void configure(ErrorReportingService service) {
    _service = service;
  }

  static void report({
    required Exception error,
    required StackTrace stackTrace,
  }) {
    _service.report(error: error, stackTrace: stackTrace);
  }
}

sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Error<T> extends Result<T> {
  Error(this.error, {StackTrace? stackTrace})
      : stackTrace = stackTrace ?? StackTrace.current {
    ResultErrorReporting.report(error: error, stackTrace: this.stackTrace);
  }

  final Exception error;
  final StackTrace stackTrace;
}
