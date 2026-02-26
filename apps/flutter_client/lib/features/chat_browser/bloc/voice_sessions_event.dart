part of "voice_sessions_bloc.dart";

sealed class VoiceSessionsEvent {
  const VoiceSessionsEvent();
}

final class ResetVoiceSessionsRequested extends VoiceSessionsEvent {
  const ResetVoiceSessionsRequested();
}

final class LoadVoiceSessionsRequested extends VoiceSessionsEvent {
  const LoadVoiceSessionsRequested({
    required this.baseUrl,
    required this.channelId,
  });

  final String baseUrl;
  final String channelId;
}

final class ConnectVoiceSessionRequested extends VoiceSessionsEvent {
  const ConnectVoiceSessionRequested({
    required this.baseUrl,
    required this.channelId,
  });

  final String baseUrl;
  final String channelId;
}

final class DisconnectVoiceSessionRequested extends VoiceSessionsEvent {
  const DisconnectVoiceSessionRequested({
    required this.baseUrl,
    required this.channelId,
  });

  final String baseUrl;
  final String channelId;
}
