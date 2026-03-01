import "dart:convert";
import "package:desktop_multi_window/desktop_multi_window.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_stream_popout_window_widget.dart";
import "package:polyphony_flutter_client/app/polyphony_app_widget.dart";

export "app/polyphony_app_widget.dart";

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

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
          VoiceStreamPopoutWindowApp(
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
