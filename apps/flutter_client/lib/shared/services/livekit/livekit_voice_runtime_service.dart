import "dart:async";

import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_runtime_service.dart";

class LivekitVoiceRuntimeService implements VoiceRuntimeService {
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  var _isSelfMuted = false;
  var _isSelfDeafened = false;

  @override
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  }) async {
    try {
      await _disconnectCurrentRoom();

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      await room.prepareConnection(livekitUrl, accessToken);
      await room.connect(livekitUrl, accessToken);
      await room.localParticipant?.setMicrophoneEnabled(true);
      _isSelfMuted = false;
      _isSelfDeafened = false;
      _roomListener = room.createListener()
        ..on<TrackSubscribedEvent>((event) {
          if (!_isSelfDeafened || event.track is! RemoteAudioTrack) {
            return;
          }

          unawaited(event.publication.unsubscribe());
        });
      _room = room;
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  Future<Result<void>> disconnect() async {
    try {
      await _disconnectCurrentRoom();
      _isSelfMuted = false;
      _isSelfDeafened = false;
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  Future<Result<void>> setSelfMuted({required bool muted}) async {
    try {
      final activeRoom = _room;
      if (activeRoom == null) {
        return Error<void>(Exception("Not connected to a voice session."));
      }

      await activeRoom.localParticipant?.setMicrophoneEnabled(!muted);
      _isSelfMuted = muted;
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  bool isSelfMuted() {
    return _isSelfMuted;
  }

  @override
  Future<Result<void>> setSelfDeafened({required bool deafened}) async {
    try {
      final activeRoom = _room;
      if (activeRoom == null) {
        return Error<void>(Exception("Not connected to a voice session."));
      }

      if (deafened) {
        await activeRoom.localParticipant?.setMicrophoneEnabled(false);
        _isSelfMuted = true;
        await _setRemoteAudioSubscriptionsEnabled(enabled: false);
      } else {
        await activeRoom.localParticipant?.setMicrophoneEnabled(true);
        _isSelfMuted = false;
        await _setRemoteAudioSubscriptionsEnabled(enabled: true);
      }

      _isSelfDeafened = deafened;
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  bool isSelfDeafened() {
    return _isSelfDeafened;
  }

  @override
  Iterable<String> currentParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>[];
    }

    final localIdentity = activeRoom.localParticipant?.identity;
    final remoteIdentities = activeRoom.remoteParticipants.values
        .map((participant) => participant.identity);

    return <String>{
      if (localIdentity != null && localIdentity.isNotEmpty) localIdentity,
      ...remoteIdentities.where((identity) => identity.isNotEmpty),
    };
  }

  Future<void> _disconnectCurrentRoom() async {
    final activeListener = _roomListener;
    _roomListener = null;
    if (activeListener != null) {
      await activeListener.dispose();
    }

    final activeRoom = _room;
    _room = null;

    if (activeRoom == null) {
      return;
    }

    await activeRoom.disconnect();
  }

  Future<void> _setRemoteAudioSubscriptionsEnabled({
    required bool enabled,
  }) async {
    final activeRoom = _room;
    if (activeRoom == null) {
      return;
    }

    for (final remoteParticipant in activeRoom.remoteParticipants.values) {
      for (final publication in remoteParticipant.audioTrackPublications) {
        if (enabled) {
          await publication.subscribe();
        } else {
          await publication.unsubscribe();
        }
      }
    }
  }
}
