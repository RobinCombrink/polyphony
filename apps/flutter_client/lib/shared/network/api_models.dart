class ApiServer {
  const ApiServer({
    required this.id,
    required this.name,
    required this.ownerSubject,
  });

  final String id;
  final String name;
  final String ownerSubject;

  factory ApiServer.fromJson(Map<String, dynamic> json) {
    return ApiServer(
      id: json["id"] as String,
      name: json["name"] as String,
      ownerSubject: json["owner_subject"] as String,
    );
  }
}

class ApiChannel {
  const ApiChannel({
    required this.id,
    required this.serverId,
    required this.name,
  });

  final String id;
  final String serverId;
  final String name;

  factory ApiChannel.fromJson(Map<String, dynamic> json) {
    return ApiChannel(
      id: json["id"] as String,
      serverId: json["server_id"] as String,
      name: json["name"] as String,
    );
  }
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.channelId,
    required this.authorSubject,
    required this.content,
  });

  final String id;
  final String channelId;
  final String authorSubject;
  final String content;

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: json["id"] as String,
      channelId: json["channel_id"] as String,
      authorSubject: json["author_subject"] as String,
      content: json["content"] as String,
    );
  }
}

class ApiVoiceConnectSession {
  const ApiVoiceConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantSubject,
  });

  final String livekitUrl;
  final String accessToken;
  final String channelId;
  final String participantSubject;

  factory ApiVoiceConnectSession.fromJson(Map<String, dynamic> json) {
    return ApiVoiceConnectSession(
      livekitUrl: json["livekit_url"] as String,
      accessToken: json["access_token"] as String,
      channelId: json["channel_id"] as String,
      participantSubject: json["participant_subject"] as String,
    );
  }
}

class ApiMe {
  const ApiMe({
    required this.userId,
    required this.displayName,
    required this.issuer,
    required this.tokenDurationHours,
  });

  final String userId;
  final String? displayName;
  final String issuer;
  final int tokenDurationHours;

  factory ApiMe.fromJson(Map<String, dynamic> json) {
    return ApiMe(
      userId: json["user_id"] as String,
      displayName: json["display_name"] as String?,
      issuer: json["issuer"] as String,
      tokenDurationHours: json["token_duration_hours"] as int,
    );
  }
}
