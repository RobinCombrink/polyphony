part of "voice_sessions_bloc.dart";

enum VoiceSessionsValidationIssue {
  channelSelectionRequired,
}

enum VoiceSessionsLoadingOperation {
  connecting,
  reconnecting,
  disconnecting,
}

enum VoiceSessionsLifecycleIssue {
  reconnectRequired,
  tokenExpired,
  channelForbidden,
}

sealed class VoiceSessionsState {
  const VoiceSessionsState();
}

final class VoiceSessionsInitialState extends VoiceSessionsState {
  const VoiceSessionsInitialState();
}

final class VoiceSessionsLoadingState extends VoiceSessionsState {
  const VoiceSessionsLoadingState({
    this.operation = VoiceSessionsLoadingOperation.connecting,
    this.channelId,
  });

  final VoiceSessionsLoadingOperation operation;
  final String? channelId;
}

sealed class VoiceSessionsLoadedDataState extends VoiceSessionsState {
  const VoiceSessionsLoadedDataState({
    required this.activeConnection,
    required this.selectedChannelId,
    required this.participants,
    required this.participantsByChannelId,
    required this.participantVideoTracks,
    required this.isSelfMuted,
    required this.isSelfDeafened,
    required this.isSelfScreenShareEnabled,
    this.isEchoCancellationEnabled = true,
    this.isNoiseSuppressionEnabled = true,
  });

  final VoiceConnectSession? activeConnection;
  final String selectedChannelId;
  final List<VoiceParticipant> participants;
  final Map<String, List<VoiceParticipant>> participantsByChannelId;
  final Map<String, Object> participantVideoTracks;
  final bool isSelfMuted;
  final bool isSelfDeafened;
  final bool isSelfScreenShareEnabled;
  final bool isEchoCancellationEnabled;
  final bool isNoiseSuppressionEnabled;

  String? get connectedChannelId => activeConnection?.channelId;
}

final class VoiceSessionsLoadedState extends VoiceSessionsLoadedDataState {
  const VoiceSessionsLoadedState({
    required super.activeConnection,
    required super.selectedChannelId,
    required super.participants,
    required super.participantsByChannelId,
    required super.participantVideoTracks,
    required super.isSelfMuted,
    required super.isSelfDeafened,
    required super.isSelfScreenShareEnabled,
    super.isEchoCancellationEnabled,
    super.isNoiseSuppressionEnabled,
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
    required super.participantVideoTracks,
    required super.isSelfMuted,
    required super.isSelfDeafened,
    required super.isSelfScreenShareEnabled,
    super.isEchoCancellationEnabled,
    super.isNoiseSuppressionEnabled,
  });

  final VoiceSessionsValidationIssue issue;
}

final class VoiceSessionsLifecycleIssueState
    extends VoiceSessionsLoadedDataState {
  const VoiceSessionsLifecycleIssueState({
    required this.issue,
    required super.activeConnection,
    required super.selectedChannelId,
    required super.participants,
    required super.participantsByChannelId,
    required super.participantVideoTracks,
    required super.isSelfMuted,
    required super.isSelfDeafened,
    required super.isSelfScreenShareEnabled,
    super.isEchoCancellationEnabled,
    super.isNoiseSuppressionEnabled,
  });

  final VoiceSessionsLifecycleIssue issue;
}

final class VoiceSessionsExceptionState extends VoiceSessionsState {
  const VoiceSessionsExceptionState({required this.error});

  final Exception error;
}
