class Server {
  const Server(
      {required this.id, required this.name, required this.ownerUserId});

  final String id;
  final String name;
  final String ownerUserId;

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json["id"] as String,
      name: json["name"] as String,
      ownerUserId: json["owner_user_id"] as String,
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
    required this.authorUserId,
    required this.content,
  });

  final String id;
  final String channelId;
  final String authorUserId;
  final String content;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json["id"] as String,
      channelId: json["channel_id"] as String,
      authorUserId: json["author_user_id"] as String,
      content: json["content"] as String,
    );
  }
}

class VoiceSession {
  const VoiceSession({
    required this.channelId,
    required this.participantUserId,
    required this.isMuted,
  });

  final String channelId;
  final String participantUserId;
  final bool isMuted;

  factory VoiceSession.fromJson(Map<String, dynamic> json) {
    return VoiceSession(
      channelId: json["channel_id"] as String,
      participantUserId: json["participant_user_id"] as String,
      isMuted: json["is_muted"] as bool? ?? false,
    );
  }
}

class VoiceConnectSession {
  const VoiceConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantUserId,
  });

  final String livekitUrl;
  final String accessToken;
  final String channelId;
  final String participantUserId;
}

class VoiceParticipant {
  const VoiceParticipant({
    required this.userId,
    required this.displayName,
    required this.isMuted,
  });

  final String userId;
  final String displayName;
  final bool isMuted;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String? displayName;
}
