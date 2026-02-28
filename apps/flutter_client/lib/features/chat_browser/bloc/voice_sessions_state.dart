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
    required this.participants,
    required this.participantsByChannelId,
    required this.isSelfMuted,
  });

  final VoiceConnectSession? activeConnection;
  final String channelId;
  final List<VoiceParticipant> participants;
  final Map<String, List<VoiceParticipant>> participantsByChannelId;
  final bool isSelfMuted;
}

final class VoiceSessionsLoadedState extends VoiceSessionsLoadedDataState {
  const VoiceSessionsLoadedState({
    required super.activeConnection,
    required super.channelId,
    required super.participants,
    required super.participantsByChannelId,
    required super.isSelfMuted,
  });
}

final class VoiceSessionsValidationFailedState
    extends VoiceSessionsLoadedDataState {
  const VoiceSessionsValidationFailedState({
    required this.issue,
    required super.activeConnection,
    required super.channelId,
    required super.participants,
    required super.participantsByChannelId,
    required super.isSelfMuted,
  });

  final VoiceSessionsValidationIssue issue;
}

final class VoiceSessionsExceptionState extends VoiceSessionsState {
  const VoiceSessionsExceptionState({required this.error});

  final Exception error;
}
