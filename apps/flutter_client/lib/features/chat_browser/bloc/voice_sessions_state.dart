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
    required this.selectedChannelId,
    required this.participants,
    required this.participantsByChannelId,
    required this.isSelfMuted,
    required this.isSelfDeafened,
  });

  final VoiceConnectSession? activeConnection;
  final String selectedChannelId;
  final List<VoiceParticipant> participants;
  final Map<String, List<VoiceParticipant>> participantsByChannelId;
  final bool isSelfMuted;
  final bool isSelfDeafened;

  String? get connectedChannelId => activeConnection?.channelId;
}

final class VoiceSessionsLoadedState extends VoiceSessionsLoadedDataState {
  const VoiceSessionsLoadedState({
    required super.activeConnection,
    required super.selectedChannelId,
    required super.participants,
    required super.participantsByChannelId,
    required super.isSelfMuted,
    required super.isSelfDeafened,
  });
}

final class VoiceSessionsValidationFailedState
    extends VoiceSessionsLoadedDataState {
  const VoiceSessionsValidationFailedState({
    required this.issue,
    required super.activeConnection,
    required super.selectedChannelId,
    required super.participants,
    required super.participantsByChannelId,
    required super.isSelfMuted,
    required super.isSelfDeafened,
  });

  final VoiceSessionsValidationIssue issue;
}

final class VoiceSessionsExceptionState extends VoiceSessionsState {
  const VoiceSessionsExceptionState({required this.error});

  final Exception error;
}
