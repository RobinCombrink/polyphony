part of "voice_sessions_bloc.dart";

sealed class VoiceSessionsEvent {
  const VoiceSessionsEvent();
}

final class ResetVoiceSessionsRequested extends VoiceSessionsEvent {
  const ResetVoiceSessionsRequested();
}

final class LoadVoiceSessionsRequested extends VoiceSessionsEvent {
  const LoadVoiceSessionsRequested({
    required this.channelId,
  });

  final ChannelId channelId;
}

final class RefreshVoiceParticipantsRequested extends VoiceSessionsEvent {
  const RefreshVoiceParticipantsRequested({
    required this.channelIds,
  });

  final List<ChannelId> channelIds;
}

final class ConnectVoiceSessionRequested extends VoiceSessionsEvent {
  const ConnectVoiceSessionRequested({
    required this.channelId,
  });

  final ChannelId channelId;
}

final class DisconnectVoiceSessionRequested extends VoiceSessionsEvent {
  const DisconnectVoiceSessionRequested({
    required this.channelId,
  });

  final ChannelId channelId;
}

final class SetSelfMutedRequested extends VoiceSessionsEvent {
  const SetSelfMutedRequested({
    required this.muted,
  });

  final bool muted;
}

final class SetSelfDeafenedRequested extends VoiceSessionsEvent {
  const SetSelfDeafenedRequested({
    required this.deafened,
  });

  final bool deafened;
}

final class SetSelfScreenShareEnabledRequested extends VoiceSessionsEvent {
  const SetSelfScreenShareEnabledRequested({
    required this.enabled,
    this.sourceId,
  });

  final bool enabled;
  final String? sourceId;
}

final class SetEchoCancellationEnabledRequested extends VoiceSessionsEvent {
  const SetEchoCancellationEnabledRequested({
    required this.enabled,
  });

  final bool enabled;
}

final class SetNoiseSuppressionEnabledRequested extends VoiceSessionsEvent {
  const SetNoiseSuppressionEnabledRequested({
    required this.enabled,
  });

  final bool enabled;
}

final class ParticipantStatusUpdated extends VoiceSessionsEvent {
  const ParticipantStatusUpdated({
    required this.update,
  });

  final ParticipantStatusUpdate update;
}

final class ParticipantUserIdsUpdated extends VoiceSessionsEvent {
  const ParticipantUserIdsUpdated({
    required this.participantUserIds,
  });

  final Set<String> participantUserIds;
}

final class ParticipantVideoTracksUpdated extends VoiceSessionsEvent {
  const ParticipantVideoTracksUpdated({
    required this.participantVideoTracks,
  });

  final Map<String, Object> participantVideoTracks;
}
