class Server {
  const Server(
      {required this.id, required this.name, required this.ownerSubject});

  final String id;
  final String name;
  final String ownerSubject;

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json["id"] as String,
      name: json["name"] as String,
      ownerSubject: json["owner_subject"] as String,
    );
  }
}

class Channel {
  const Channel({required this.id, required this.serverId, required this.name});

  final String id;
  final String serverId;
  final String name;

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json["id"] as String,
      serverId: json["server_id"] as String,
      name: json["name"] as String,
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.channelId,
    required this.authorSubject,
    required this.content,
  });

  final String id;
  final String channelId;
  final String authorSubject;
  final String content;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json["id"] as String,
      channelId: json["channel_id"] as String,
      authorSubject: json["author_subject"] as String,
      content: json["content"] as String,
    );
  }
}

class VoiceSession {
  const VoiceSession({
    required this.channelId,
    required this.participantSubject,
  });

  final String channelId;
  final String participantSubject;

  factory VoiceSession.fromJson(Map<String, dynamic> json) {
    return VoiceSession(
      channelId: json["channel_id"] as String,
      participantSubject: json["participant_subject"] as String,
    );
  }
}

class VoiceConnectSession {
  const VoiceConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantSubject,
  });

  final String livekitUrl;
  final String accessToken;
  final String channelId;
  final String participantSubject;
}
