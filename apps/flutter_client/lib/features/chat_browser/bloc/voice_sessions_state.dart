part of "voice_sessions_bloc.dart";

enum VoiceSessionsValidationIssue {
  channelSelectionRequired,
}

sealed class VoiceSessionsState {
  const VoiceSessionsState();
}

final class VoiceSessionsInitialState extends VoiceSessionsState {
  const VoiceSessionsInitialState();
}

final class VoiceSessionsLoadingState extends VoiceSessionsState {
  const VoiceSessionsLoadingState();
}

sealed class VoiceSessionsLoadedDataState extends VoiceSessionsState {
  const VoiceSessionsLoadedDataState({
    required this.activeConnection,
    required this.channelId,
  });

  final VoiceConnectSession? activeConnection;
  final String channelId;
}

final class VoiceSessionsLoadedState extends VoiceSessionsLoadedDataState {
  const VoiceSessionsLoadedState({
    required super.activeConnection,
    required super.channelId,
  });
}

final class VoiceSessionsValidationFailedState
    extends VoiceSessionsLoadedDataState {
  const VoiceSessionsValidationFailedState({
    required this.issue,
    required super.activeConnection,
    required super.channelId,
  });

  final VoiceSessionsValidationIssue issue;
}

final class VoiceSessionsExceptionState extends VoiceSessionsState {
  const VoiceSessionsExceptionState({required this.error});

  final Exception error;
}
