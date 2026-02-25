part of "voice_sessions_bloc.dart";

enum VoiceSessionsValidationIssue {
  channelSelectionRequired,
}

sealed class VoiceSessionsState {
  const VoiceSessionsState({
    required this.voiceSessions,
    required this.channelId,
  });

  final List<VoiceSession> voiceSessions;
  final String? channelId;

  bool get isLoading => this is VoiceSessionsLoadingState;
}

final class VoiceSessionsInitialState extends VoiceSessionsState {
  const VoiceSessionsInitialState()
      : super(voiceSessions: const <VoiceSession>[], channelId: null);
}

final class VoiceSessionsLoadingState extends VoiceSessionsState {
  const VoiceSessionsLoadingState({
    required super.voiceSessions,
    required super.channelId,
  });
}

final class VoiceSessionsLoadedState extends VoiceSessionsState {
  const VoiceSessionsLoadedState({
    required super.voiceSessions,
    required super.channelId,
  });
}

final class VoiceSessionsValidationFailedState extends VoiceSessionsState {
  const VoiceSessionsValidationFailedState({
    required this.issue,
    required super.voiceSessions,
    required super.channelId,
  });

  final VoiceSessionsValidationIssue issue;
}

final class VoiceSessionsExceptionState extends VoiceSessionsState {
  const VoiceSessionsExceptionState({
    required this.error,
    required super.voiceSessions,
    required super.channelId,
  });

  final Exception error;
}
