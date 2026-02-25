import 'dart:math';

import 'package:polyphony_flutter_client/shared/models/chat_models.dart';

class ChatApiFixture {
  const ChatApiFixture({
    required this.ownerSubject,
    required this.listedServer,
    required this.createdServer,
    required this.listedChannel,
    required this.createdChannel,
    required this.listedMessage,
    required this.createdMessage,
  });

  final String ownerSubject;
  final Server listedServer;
  final Server createdServer;
  final Channel listedChannel;
  final Channel createdChannel;
  final Message listedMessage;
  final Message createdMessage;
}

class EntitySeeder {
  static final Random _random = Random();

  String authSubject({String? value}) {
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }

    return 'auth0|user_${_randomSegment()}';
  }

  ChatApiFixture chatApiFixture() {
    const ownerSubject = 'auth0|u1';

    final listedServer = server(id: 'srv-1', ownerSubject: ownerSubject);
    final createdServer = server(id: 'srv-2', ownerSubject: ownerSubject);
    final listedChannel = channel(id: 'chn-1', serverId: listedServer.id);
    final createdChannel = channel(id: 'chn-2', serverId: listedServer.id);
    final listedMessage = message(
      id: 'msg-1',
      channelId: listedChannel.id,
      authorSubject: ownerSubject,
      content: 'hello',
    );
    final createdMessage = message(
      id: 'msg-2',
      channelId: listedChannel.id,
      authorSubject: ownerSubject,
      content: 'new message',
    );

    return ChatApiFixture(
      ownerSubject: ownerSubject,
      listedServer: listedServer,
      createdServer: createdServer,
      listedChannel: listedChannel,
      createdChannel: createdChannel,
      listedMessage: listedMessage,
      createdMessage: createdMessage,
    );
  }

  Server server({String? id, String? name, String? ownerSubject}) {
    final randomSegment = _randomSegment();

    return Server(
      id: id ?? 'srv-seeded-$randomSegment',
      name: name ?? 'Server-$randomSegment',
      ownerSubject: authSubject(value: ownerSubject),
    );
  }

  Channel channel({required String serverId, String? id, String? name}) {
    final randomSegment = _randomSegment();

    return Channel(
      id: id ?? 'chn-seeded-$randomSegment',
      serverId: serverId,
      name: name ?? 'Channel-$randomSegment',
    );
  }

  Message message({
    required String channelId,
    required String authorSubject,
    String? id,
    String? content,
  }) {
    final randomSegment = _randomSegment();

    return Message(
      id: id ?? 'msg-seeded-$randomSegment',
      channelId: channelId,
      authorSubject: authorSubject,
      content: content ?? 'Message-$randomSegment',
    );
  }

  Map<String, dynamic> serverJson(Server server) {
    return <String, dynamic>{
      'id': server.id,
      'name': server.name,
      'owner_subject': server.ownerSubject,
    };
  }

  Map<String, dynamic> channelJson(Channel channel) {
    return <String, dynamic>{
      'id': channel.id,
      'server_id': channel.serverId,
      'name': channel.name,
    };
  }

  Map<String, dynamic> messageJson(Message message) {
    return <String, dynamic>{
      'id': message.id,
      'channel_id': message.channelId,
      'author_subject': message.authorSubject,
      'content': message.content,
    };
  }

  String _randomSegment() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

    return List<String>.generate(
      8,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
