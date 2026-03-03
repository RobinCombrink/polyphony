import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_stream_popout_window_widget.dart";

class HomeVoiceStreamPopoutWindowApp extends StatelessWidget {
  const HomeVoiceStreamPopoutWindowApp({required this.arguments, super.key});

  final String arguments;

  @override
  Widget build(BuildContext context) {
    return VoiceStreamPopoutWindowApp(arguments: arguments);
  }
}
