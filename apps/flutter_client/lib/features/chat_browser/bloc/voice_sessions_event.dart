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

  final String channelId;
}

final class RefreshVoiceParticipantsRequested extends VoiceSessionsEvent {
  const RefreshVoiceParticipantsRequested({
    required this.channelIds,
  });

  final List<String> channelIds;
}

final class ConnectVoiceSessionRequested extends VoiceSessionsEvent {
  const ConnectVoiceSessionRequested({
    required this.channelId,
  });

  final String channelId;
}

final class DisconnectVoiceSessionRequested extends VoiceSessionsEvent {
  const DisconnectVoiceSessionRequested({
    required this.channelId,
  });

  final String channelId;
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

final class SpeakingParticipantUserIdsUpdated extends VoiceSessionsEvent {
  const SpeakingParticipantUserIdsUpdated({
    required this.speakingParticipantUserIds,
  });

  final Set<String> speakingParticipantUserIds;
}

final class ParticipantUserIdsUpdated extends VoiceSessionsEvent {
  const ParticipantUserIdsUpdated({
    required this.participantUserIds,
  });

  final Set<String> participantUserIds;
}

final class MutedParticipantUserIdsUpdated extends VoiceSessionsEvent {
  const MutedParticipantUserIdsUpdated({
    required this.mutedParticipantUserIds,
  });

  final Set<String> mutedParticipantUserIds;
}

final class ParticipantVideoTracksUpdated extends VoiceSessionsEvent {
  const ParticipantVideoTracksUpdated({
    required this.participantVideoTracks,
  });

  final Map<String, Object> participantVideoTracks;
}
