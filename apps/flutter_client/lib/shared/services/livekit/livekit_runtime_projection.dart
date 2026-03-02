import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

extension type ParticipantIdentity._(String value) {
  static ParticipantIdentity? fromRaw(String? rawIdentity) {
    final trimmedIdentity = rawIdentity?.trim();
    if (trimmedIdentity == null || trimmedIdentity.isEmpty) {
      return null;
    }

    return ParticipantIdentity._(trimmedIdentity);
  }

  ParticipantUserId toUserId() {
    final separatorIndex = value.indexOf(":");
    final rawUserId =
        separatorIndex <= 0 ? value : value.substring(0, separatorIndex);
    return ParticipantUserId._(rawUserId);
  }
}

extension type ParticipantUserId._(String value) {
  static ParticipantUserId? fromRaw(String? rawUserId) {
    final trimmedUserId = rawUserId?.trim();
    if (trimmedUserId == null || trimmedUserId.isEmpty) {
      return null;
    }

    return ParticipantUserId._(trimmedUserId);
  }

  String get rawValue => value;
}

sealed class ParticipantAudioState {
  const ParticipantAudioState();

  static ParticipantAudioState fromMutedFlag(bool isMuted) {
    return isMuted ? const MutedAudioState() : const UnmutedAudioState();
  }
}

final class MutedAudioState extends ParticipantAudioState {
  const MutedAudioState();
}

final class UnmutedAudioState extends ParticipantAudioState {
  const UnmutedAudioState();
}

sealed class ParticipantDeafenState {
  const ParticipantDeafenState();

  static ParticipantDeafenState fromBool(bool isDeafened) {
    return isDeafened ? const DeafenedState() : const NotDeafenedState();
  }

  factory ParticipantDeafenState.fromAttribute(String? attributeValue) {
    final normalizedValue = attributeValue?.trim().toLowerCase();
    return normalizedValue == "true"
        ? const DeafenedState()
        : const NotDeafenedState();
  }
}

final class DeafenedState extends ParticipantDeafenState {
  const DeafenedState();
}

final class NotDeafenedState extends ParticipantDeafenState {
  const NotDeafenedState();
}

class ParticipantAudioSnapshot {
  const ParticipantAudioSnapshot({
    required this.identity,
    required this.audioState,
  });

  final ParticipantIdentity? identity;
  final ParticipantAudioState audioState;
}

class ParticipantDeafenSnapshot {
  const ParticipantDeafenSnapshot({
    required this.identity,
    required this.deafenState,
  });

  final ParticipantIdentity? identity;
  final ParticipantDeafenState deafenState;
}

class LivekitRuntimeProjection {
  static Set<ParticipantUserId> participantUserIds({
    required ParticipantIdentity? localIdentity,
    required Iterable<ParticipantIdentity> remoteIdentities,
  }) {
    return <ParticipantUserId>{
      if (localIdentity != null) localIdentity.toUserId(),
      ...remoteIdentities.map((identity) => identity.toUserId()),
    };
  }

  static Map<ParticipantUserId, RuntimeAudioChannel> synchronizedAudioChannels({
    required Map<ParticipantUserId, RuntimeAudioChannel> existingChannels,
    required Set<ParticipantUserId> participantUserIds,
  }) {
    return <ParticipantUserId, RuntimeAudioChannel>{
      for (final participantUserId in participantUserIds)
        participantUserId:
            existingChannels[participantUserId] ?? RuntimeAudioChannel.voice,
    };
  }

  static Set<ParticipantUserId> mutedParticipantUserIds({
    required ParticipantIdentity? localIdentity,
    required ParticipantAudioState localAudioState,
    required Iterable<ParticipantAudioSnapshot> remoteParticipantAudio,
  }) {
    final mutedParticipantUserIds = <ParticipantUserId>{};

    if (localIdentity != null && localAudioState is MutedAudioState) {
      mutedParticipantUserIds.add(localIdentity.toUserId());
    }

    for (final remoteAudioSnapshot in remoteParticipantAudio) {
      if (remoteAudioSnapshot.identity == null ||
          remoteAudioSnapshot.audioState is UnmutedAudioState) {
        continue;
      }

      mutedParticipantUserIds.add(remoteAudioSnapshot.identity!.toUserId());
    }

    return mutedParticipantUserIds;
  }

  static Set<ParticipantUserId> deafenedParticipantUserIds({
    required ParticipantIdentity? localIdentity,
    required ParticipantDeafenState localDeafenState,
    required Iterable<ParticipantDeafenSnapshot> remoteParticipantDeafen,
  }) {
    final deafenedParticipantUserIds = <ParticipantUserId>{};

    if (localIdentity != null && localDeafenState is DeafenedState) {
      deafenedParticipantUserIds.add(localIdentity.toUserId());
    }

    for (final remoteDeafenSnapshot in remoteParticipantDeafen) {
      if (remoteDeafenSnapshot.identity == null ||
          remoteDeafenSnapshot.deafenState is NotDeafenedState) {
        continue;
      }

      deafenedParticipantUserIds.add(remoteDeafenSnapshot.identity!.toUserId());
    }

    return deafenedParticipantUserIds;
  }

  static Set<String> rawParticipantUserIds(
      Set<ParticipantUserId> participantUserIds) {
    return participantUserIds
        .map((participantUserId) => participantUserId.rawValue)
        .toSet();
  }
}
