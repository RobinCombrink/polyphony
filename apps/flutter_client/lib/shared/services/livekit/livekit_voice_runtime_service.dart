import "dart:async";

import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_runtime_service.dart";

class LivekitVoiceRuntimeService implements VoiceRuntimeService {
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

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
      _roomListener = room.createListener();
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
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  Iterable<String> currentParticipantSubjects() {
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
}
