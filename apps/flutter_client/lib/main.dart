import "dart:convert";

import "package:desktop_multi_window/desktop_multi_window.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:polyphony_flutter_client/app/polyphony_app_widget.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/home_voice_stream_popout_window_widget.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/result/sentry_error_reporting_service.dart";
import "package:sentry_flutter/sentry_flutter.dart";

export "app/polyphony_app_widget.dart";

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final sentryDsn = PolyphonyConfig.sentryDsn.trim();
  final isSentryEnabled = PolyphonyConfig.sentryEnabled && sentryDsn.isNotEmpty;

  if (!isSentryEnabled) {
    ResultErrorReporting.configure(const NoopErrorReportingService());
    await _runPolyphonyApp(args);
    return;
  }

  await SentryFlutter.init((options) {
    final sentryEnvironment = PolyphonyConfig.sentryEnvironment.trim();
    final sentryRelease = PolyphonyConfig.sentryRelease.trim();

    options
      ..dsn = sentryDsn
      ..sendDefaultPii = false
      ..tracesSampleRate = PolyphonyConfig.sentryTracesSampleRate();

    if (sentryEnvironment.isNotEmpty) {
      options.environment = sentryEnvironment;
    }

    if (sentryRelease.isNotEmpty) {
      options.release = sentryRelease;
    }
  });

  ResultErrorReporting.configure(
    const FilteredErrorReportingService(
      delegate: SentryErrorReportingService(),
      ignoreCallbacks: <ErrorIgnoreCallback>[
        _shouldIgnoreError,
      ],
    ),
  );

  await _runPolyphonyApp(args);
}

bool _shouldIgnoreError(Exception error) {
  return switch (error) {
    ApiRequestException(:final statusCode) => statusCode == 404,
    _ => false,
  };
}

Future<void> _runPolyphonyApp(List<String> args) async {
  if (!_isDesktopRuntime()) {
    runApp(const PolyphonyApp());
    return;
  }

  try {
    final windowController = await WindowController.fromCurrentEngine();
    final argumentsMap = _decodeArguments(windowController.arguments);
    final windowType = (argumentsMap["type"] as String? ?? "main").trim();

    switch (windowType) {
      case "voice_stream_popout":
        runApp(
          HomeVoiceStreamPopoutWindowApp(
            arguments: windowController.arguments,
          ),
        );
      default:
        runApp(const PolyphonyApp());
    }
  } on MissingPluginException {
    runApp(const PolyphonyApp());
  } on Exception {
    runApp(const PolyphonyApp());
  }
}

Map<String, Object?> _decodeArguments(String arguments) {
  try {
    final decoded = jsonDecode(arguments);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return const <String, Object?>{};
  } on FormatException {
    return const <String, Object?>{};
  }
}

bool _isDesktopRuntime() {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
}
