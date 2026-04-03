import "dart:math";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

class ChatApiFixture {
  const ChatApiFixture({
    required this.ownerUserId,
    required this.listedServer,
    required this.createdServer,
    required this.listedChannel,
    required this.createdChannel,
    required this.listedVoiceChannel,
    required this.createdVoiceChannel,
    required this.listedMessage,
    required this.createdMessage,
    required this.connectedVoiceSession,
  });

  final UserId ownerUserId;
  final Server listedServer;
  final Server createdServer;
  final Channel listedChannel;
  final Channel createdChannel;
  final Channel listedVoiceChannel;
  final Channel createdVoiceChannel;
  final Message listedMessage;
  final Message createdMessage;
  final VoiceConnectSession connectedVoiceSession;
}

class EntitySeeder {
  static final _random = Random();

  UserId authUserId({UserId? value}) {
    if (value != null && value.value.trim().isNotEmpty) {
      return value;
    }

    return UserId("auth0|user_${_randomSegment()}");
  }

  ChatApiFixture chatApiFixture() {
    const ownerUserId = UserId("auth0|u1");

    final listedServer =
        server(id: const ServerId("srv-1"), ownerUserId: ownerUserId);
    final createdServer =
        server(id: const ServerId("srv-2"), ownerUserId: ownerUserId);
    final listedChannel = textChannel(
      id: const ChannelId("chn-1"),
      serverId: listedServer.id,
    );
    final createdChannel = textChannel(
      id: const ChannelId("chn-2"),
      serverId: listedServer.id,
    );
    final listedVoiceChannel = voiceChannel(
      id: const ChannelId("vch-1"),
      serverId: listedServer.id,
    );
    final createdVoiceChannel = voiceChannel(
      id: const ChannelId("vch-2"),
      serverId: listedServer.id,
    );
    final listedMessage = message(
      id: const MessageId("msg-1"),
      channelId: listedChannel.id,
      authorUserId: ownerUserId,
      content: "hello",
    );
    final createdMessage = message(
      id: const MessageId("msg-2"),
      channelId: listedChannel.id,
      authorUserId: ownerUserId,
      content: "new message",
    );
    final connectedVoiceSession = voiceConnectSession(
      livekitUrl: "ws://127.0.0.1:7880",
      accessToken: "test-access-token",
      channelId: listedVoiceChannel.id,
      participantUserId: ownerUserId,
    );

    return ChatApiFixture(
      ownerUserId: ownerUserId,
      listedServer: listedServer,
      createdServer: createdServer,
      listedChannel: listedChannel,
      createdChannel: createdChannel,
      listedVoiceChannel: listedVoiceChannel,
      createdVoiceChannel: createdVoiceChannel,
      listedMessage: listedMessage,
      createdMessage: createdMessage,
      connectedVoiceSession: connectedVoiceSession,
    );
  }

  Server server({ServerId? id, String? name, UserId? ownerUserId}) {
    final randomSegment = _randomSegment();

    return Server(
      id: id ?? ServerId("srv-seeded-$randomSegment"),
      name: name ?? "Server-$randomSegment",
      ownerUserId: authUserId(value: ownerUserId),
    );
  }

  TextChannel textChannel({
    required ServerId serverId,
    ChannelId? id,
    String? name,
  }) {
    final randomSegment = _randomSegment();

    final resolvedId = id ?? ChannelId("chn-seeded-$randomSegment");
    final resolvedName = name ?? "Channel-$randomSegment";

    return TextChannel(
      id: resolvedId,
      serverId: serverId,
      name: resolvedName,
    );
  }

  VoiceChannel voiceChannel({
    required ServerId serverId,
    ChannelId? id,
    String? name,
  }) {
    final randomSegment = _randomSegment();

    final resolvedId = id ?? ChannelId("chn-seeded-$randomSegment");
    final resolvedName = name ?? "Channel-$randomSegment";

    return VoiceChannel(
      id: resolvedId,
      serverId: serverId,
      name: resolvedName,
    );
  }

  Message message({
    required ChannelId channelId,
    required UserId authorUserId,
    MessageId? id,
    String? content,
  }) {
    final randomSegment = _randomSegment();

    return Message(
      id: id ?? MessageId("msg-seeded-$randomSegment"),
      channelId: channelId,
      authorUserId: authorUserId,
      content: content ?? "Message-$randomSegment",
    );
  }

  VoiceConnectSession voiceConnectSession({
    required String livekitUrl,
    required String accessToken,
    required ChannelId channelId,
    required UserId participantUserId,
  }) {
    return VoiceConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId,
      participantUserId: participantUserId,
    );
  }

  Map<String, dynamic> serverJson(Server server) {
    return <String, dynamic>{
      "id": server.id.value,
      "name": server.name,
      "owner_user_id": server.ownerUserId.value,
    };
  }

  Map<String, dynamic> channelJson(Channel channel) {
    return <String, dynamic>{
      "id": channel.id.value,
      "server_id": channel.serverId.value,
      "name": channel.name,
      "channel_type": channel.channelType.apiValue,
    };
  }

  Map<String, dynamic> messageJson(Message message) {
    return <String, dynamic>{
      "id": message.id.value,
      "channel_id": message.channelId.value,
      "author_user_id": message.authorUserId.value,
      "content": message.content,
    };
  }

  Map<String, dynamic> voiceConnectSessionJson(
    VoiceConnectSession voiceConnectSession,
  ) {
    return <String, dynamic>{
      "livekit_url": voiceConnectSession.livekitUrl,
      "access_token": voiceConnectSession.accessToken,
      "channel_id": voiceConnectSession.channelId.value,
      "participant_user_id": voiceConnectSession.participantUserId.value,
    };
  }

  String _randomSegment() {
    const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789";

    return List<String>.generate(
      8,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
