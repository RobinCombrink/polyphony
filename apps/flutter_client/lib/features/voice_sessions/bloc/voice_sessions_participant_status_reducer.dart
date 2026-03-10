part of "voice_sessions_bloc.dart";

final class ParticipantStatusReducerResult {
  const ParticipantStatusReducerResult({
    required this.speakingParticipantUserIds,
    required this.nextState,
  });

  final Set<String> speakingParticipantUserIds;
  final VoiceSessionsLoadedState? nextState;
}

final class ParticipantStatusReducer {
  static ParticipantStatusReducerResult reduce({
    required VoiceSessionsLoadedDataState loadedState,
    required ParticipantStatusUpdate statusUpdate,
    required Set<String> speakingParticipantUserIds,
  }) {
    final updatedSpeakingParticipantUserIds = _reduceSpeakingParticipantUserIds(
      speakingParticipantUserIds: speakingParticipantUserIds,
      statusUpdate: statusUpdate,
    );

    final reducedParticipants = _reduceParticipantsByChannelId(
      participantsByChannelId: loadedState.participantsByChannelId,
      statusUpdate: statusUpdate,
    );

    if (!reducedParticipants.didChangeParticipants) {
      return ParticipantStatusReducerResult(
        speakingParticipantUserIds: updatedSpeakingParticipantUserIds,
        nextState: null,
      );
    }

    final activeConnection = loadedState.activeConnection;
    final selectedParticipants = reducedParticipants
            .participantsByChannelId[loadedState.selectedChannelId] ??
        loadedState.participants;

    return ParticipantStatusReducerResult(
      speakingParticipantUserIds: updatedSpeakingParticipantUserIds,
      nextState: VoiceSessionsLoadedState(
        activeConnection: activeConnection,
        selectedChannelId: loadedState.selectedChannelId,
        participants: selectedParticipants,
        participantsByChannelId: reducedParticipants.participantsByChannelId,
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: _isSelfMutedAfterUpdate(
          loadedState: loadedState,
          statusUpdate: statusUpdate,
        ),
        isSelfDeafened: _isSelfDeafenedAfterUpdate(
          loadedState: loadedState,
          statusUpdate: statusUpdate,
        ),
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ),
    );
  }

  static Set<String> _reduceSpeakingParticipantUserIds({
    required Set<String> speakingParticipantUserIds,
    required ParticipantStatusUpdate statusUpdate,
  }) {
    if (statusUpdate case ParticipantSpeakingStatusUpdated()) {
      return statusUpdate.isSpeaking
          ? <String>{
              ...speakingParticipantUserIds,
              statusUpdate.participantUserId,
            }
          : speakingParticipantUserIds
              .where((userId) => userId != statusUpdate.participantUserId)
              .toSet();
    }

    return Set<String>.from(speakingParticipantUserIds);
  }

  static _ParticipantsByChannelReduction _reduceParticipantsByChannelId({
    required Map<String, List<VoiceParticipant>> participantsByChannelId,
    required ParticipantStatusUpdate statusUpdate,
  }) {
    return participantsByChannelId.entries.fold(
      _ParticipantsByChannelReduction.empty(),
      (reduction, entry) {
        final reducedParticipants = _reduceParticipants(
          participants: entry.value,
          statusUpdate: statusUpdate,
        );

        return reduction.withEntry(
          channelId: entry.key,
          participants: reducedParticipants.participants,
          didChangeParticipants: reducedParticipants.didChangeParticipants,
        );
      },
    );
  }

  static _ParticipantListReduction _reduceParticipants({
    required List<VoiceParticipant> participants,
    required ParticipantStatusUpdate statusUpdate,
  }) {
    return participants.fold(
      _ParticipantListReduction.empty(),
      (reduction, participant) {
        final updatedParticipant =
            participant.userId == statusUpdate.participantUserId
                ? _updatedParticipant(
                    participant: participant,
                    statusUpdate: statusUpdate,
                  )
                : participant;

        return reduction.append(
          participant: updatedParticipant,
          didChange: updatedParticipant != participant,
        );
      },
    );
  }

  static bool _isSelfMutedAfterUpdate({
    required VoiceSessionsLoadedDataState loadedState,
    required ParticipantStatusUpdate statusUpdate,
  }) {
    return switch (statusUpdate) {
      ParticipantMutedStatusUpdated(
        :final participantUserId,
        :final isMuted,
      )
          when loadedState.activeConnection != null &&
              participantUserId ==
                  loadedState.activeConnection!.participantUserId =>
        isMuted,
      _ => loadedState.isSelfMuted,
    };
  }

  static bool _isSelfDeafenedAfterUpdate({
    required VoiceSessionsLoadedDataState loadedState,
    required ParticipantStatusUpdate statusUpdate,
  }) {
    return switch (statusUpdate) {
      ParticipantDeafenedStatusUpdated(
        :final participantUserId,
        :final isDeafened,
      )
          when loadedState.activeConnection != null &&
              participantUserId ==
                  loadedState.activeConnection!.participantUserId =>
        isDeafened,
      _ => loadedState.isSelfDeafened,
    };
  }

  static VoiceParticipant _updatedParticipant({
    required VoiceParticipant participant,
    required ParticipantStatusUpdate statusUpdate,
  }) {
    return switch (statusUpdate) {
      ParticipantSpeakingStatusUpdated(:final isSpeaking) => VoiceParticipant(
          userId: participant.userId,
          displayName: participant.displayName,
          isMuted: participant.isMuted,
          isDeafened: participant.isDeafened,
          isSpeaking: isSpeaking,
        ),
      ParticipantMutedStatusUpdated(:final isMuted) => VoiceParticipant(
          userId: participant.userId,
          displayName: participant.displayName,
          isMuted: isMuted,
          isDeafened: participant.isDeafened,
          isSpeaking: participant.isSpeaking,
        ),
      ParticipantDeafenedStatusUpdated(:final isDeafened) => VoiceParticipant(
          userId: participant.userId,
          displayName: participant.displayName,
          isMuted: participant.isMuted,
          isDeafened: isDeafened,
          isSpeaking: participant.isSpeaking,
        ),
    };
  }
}

final class _ParticipantsByChannelReduction {
  const _ParticipantsByChannelReduction({
    required this.participantsByChannelId,
    required this.didChangeParticipants,
  });

  factory _ParticipantsByChannelReduction.empty() {
    return const _ParticipantsByChannelReduction(
      participantsByChannelId: <String, List<VoiceParticipant>>{},
      didChangeParticipants: false,
    );
  }

  final Map<String, List<VoiceParticipant>> participantsByChannelId;
  final bool didChangeParticipants;

  _ParticipantsByChannelReduction withEntry({
    required String channelId,
    required List<VoiceParticipant> participants,
    required bool didChangeParticipants,
  }) {
    return _ParticipantsByChannelReduction(
      participantsByChannelId: <String, List<VoiceParticipant>>{
        ...participantsByChannelId,
        channelId: participants,
      },
      didChangeParticipants:
          this.didChangeParticipants || didChangeParticipants,
    );
  }
}

final class _ParticipantListReduction {
  const _ParticipantListReduction({
    required this.participants,
    required this.didChangeParticipants,
  });

  factory _ParticipantListReduction.empty() {
    return const _ParticipantListReduction(
      participants: <VoiceParticipant>[],
      didChangeParticipants: false,
    );
  }

  final List<VoiceParticipant> participants;
  final bool didChangeParticipants;

  _ParticipantListReduction append({
    required VoiceParticipant participant,
    required bool didChange,
  }) {
    return _ParticipantListReduction(
      participants: <VoiceParticipant>[
        ...participants,
        participant,
      ],
      didChangeParticipants: didChangeParticipants || didChange,
    );
  }
}
