import "dart:async";
import "dart:convert";

import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";

class LivekitMessageRuntimeService implements MessageRuntimeService {
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  final _textMessagesController =
      StreamController<RuntimeTextMessage>.broadcast();

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

      final listener = room.createListener()
        ..on<DataReceivedEvent>((event) {
          final participant = event.participant;
          if (participant == null) {
            return;
          }

          try {
            final decoded = utf8.decode(event.data);
            final payload = jsonDecode(decoded) as Map<String, dynamic>;
            final channelId = payload["channel_id"] as String?;
            final content = payload["content"] as String?;

            if (channelId == null || channelId.isEmpty) {
              return;
            }

            if (content == null || content.trim().isEmpty) {
              return;
            }

            _textMessagesController.add(
              RuntimeTextMessage(
                channelId: channelId,
                authorSubject: participant.identity,
                content: content,
              ),
            );
          } on Exception {
            return;
          }
        });

      _roomListener = listener;
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
  Stream<RuntimeTextMessage> textMessages() {
    return _textMessagesController.stream;
  }

  @override
  Future<Result<void>> sendTextMessage({
    required String channelId,
    required String content,
  }) async {
    final activeRoom = _room;
    final localParticipant = activeRoom?.localParticipant;

    if (activeRoom == null || localParticipant == null) {
      return Error<void>(Exception("LiveKit room is not connected."));
    }

    final trimmedChannelId = channelId.trim();
    final trimmedContent = content.trim();

    if (trimmedChannelId.isEmpty) {
      return Error<void>(Exception("Channel id is required."));
    }

    if (trimmedContent.isEmpty) {
      return Error<void>(Exception("Message content is required."));
    }

    try {
      final payload = <String, dynamic>{
        "channel_id": trimmedChannelId,
        "content": trimmedContent,
      };

      await localParticipant.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
        topic: "polyphony:text",
      );

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
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
