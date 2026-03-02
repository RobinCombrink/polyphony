import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/shared/services/livekit/livekit_runtime_projection.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

void main() {
  group("LivekitRuntimeProjection", () {
    test("parses participant identity and derives user id", () {
      final identity = ParticipantIdentity.fromRaw("auth0|u1:popout-123");
      expect(identity, isNotNull);
      expect(identity!.toUserId().rawValue, "auth0|u1");

      expect(ParticipantIdentity.fromRaw(""), isNull);
      expect(ParticipantIdentity.fromRaw(null), isNull);
    });

    test("collects participant user ids from local and remote identities", () {
      final participantUserIds = LivekitRuntimeProjection.participantUserIds(
        localIdentity: ParticipantIdentity.fromRaw("auth0|self:main"),
        remoteIdentities: <ParticipantIdentity>[
          ParticipantIdentity.fromRaw("auth0|u2")!,
          ParticipantIdentity.fromRaw("auth0|u3:popout")!,
        ],
      );

      expect(
        LivekitRuntimeProjection.rawParticipantUserIds(participantUserIds),
        equals(
          <String>{"auth0|self", "auth0|u2", "auth0|u3"},
        ),
      );
    });

    test("synchronizes audio channels with defaults for new members", () {
      final synchronized = LivekitRuntimeProjection.synchronizedAudioChannels(
        existingChannels: <ParticipantUserId, RuntimeAudioChannel>{
          ParticipantUserId.fromRaw("auth0|self")!:
              RuntimeAudioChannel.livestream,
          ParticipantUserId.fromRaw("auth0|stale")!: RuntimeAudioChannel.voice,
        },
        participantUserIds: <ParticipantUserId>{
          ParticipantUserId.fromRaw("auth0|self")!,
          ParticipantUserId.fromRaw("auth0|u2")!,
        },
      );

      expect(
        synchronized[ParticipantUserId.fromRaw("auth0|self")!],
        RuntimeAudioChannel.livestream,
      );
      expect(
        synchronized[ParticipantUserId.fromRaw("auth0|u2")!],
        RuntimeAudioChannel.voice,
      );
      expect(
        synchronized.containsKey(ParticipantUserId.fromRaw("auth0|stale")!),
        isFalse,
      );
    });

    test("collects muted participant user ids with self and remotes", () {
      final muted = LivekitRuntimeProjection.mutedParticipantUserIds(
        localIdentity: ParticipantIdentity.fromRaw("auth0|self"),
        localAudioState: const MutedAudioState(),
        remoteParticipantAudio: <ParticipantAudioSnapshot>[
          ParticipantAudioSnapshot(
            identity: ParticipantIdentity.fromRaw("auth0|u2"),
            audioState: const MutedAudioState(),
          ),
          ParticipantAudioSnapshot(
            identity: ParticipantIdentity.fromRaw("auth0|u3"),
            audioState: const UnmutedAudioState(),
          ),
        ],
      );

      expect(
        LivekitRuntimeProjection.rawParticipantUserIds(muted),
        equals(
          <String>{"auth0|self", "auth0|u2"},
        ),
      );
    });

    test("collects deafened participant user ids with self and remotes", () {
      final deafened = LivekitRuntimeProjection.deafenedParticipantUserIds(
        localIdentity: ParticipantIdentity.fromRaw("auth0|self"),
        localDeafenState: const DeafenedState(),
        remoteParticipantDeafen: <ParticipantDeafenSnapshot>[
          ParticipantDeafenSnapshot(
            identity: ParticipantIdentity.fromRaw("auth0|u2"),
            deafenState: const DeafenedState(),
          ),
          ParticipantDeafenSnapshot(
            identity: ParticipantIdentity.fromRaw("auth0|u3"),
            deafenState: const NotDeafenedState(),
          ),
        ],
      );

      expect(
        LivekitRuntimeProjection.rawParticipantUserIds(deafened),
        equals(<String>{"auth0|self", "auth0|u2"}),
      );
    });

    test("parses deafen state from attribute value case-insensitively", () {
      expect(
        ParticipantDeafenState.fromAttribute("TRUE"),
        isA<DeafenedState>(),
      );
      expect(
        ParticipantDeafenState.fromAttribute(" true "),
        isA<DeafenedState>(),
      );
      expect(
        ParticipantDeafenState.fromAttribute("false"),
        isA<NotDeafenedState>(),
      );
      expect(
        ParticipantDeafenState.fromAttribute(null),
        isA<NotDeafenedState>(),
      );
    });
  });
}
