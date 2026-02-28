class ApiServer {
  const ApiServer({
    required this.id,
    required this.name,
    required this.ownerUserId,
  });

  final String id;
  final String name;
  final String ownerUserId;

  factory ApiServer.fromJson(Map<String, dynamic> json) {
    return ApiServer(
      id: json["id"] as String,
      name: json["name"] as String,
      ownerUserId: json["owner_user_id"] as String,
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
    required this.authorUserId,
    required this.content,
  });

  final String id;
  final String channelId;
  final String authorUserId;
  final String content;

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: json["id"] as String,
      channelId: json["channel_id"] as String,
      authorUserId: json["author_user_id"] as String,
      content: json["content"] as String,
    );
  }
}

class ApiVoiceConnectSession {
  const ApiVoiceConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantUserId,
  });

  final String livekitUrl;
  final String accessToken;
  final String channelId;
  final String participantUserId;

  factory ApiVoiceConnectSession.fromJson(Map<String, dynamic> json) {
    return ApiVoiceConnectSession(
      livekitUrl: json["livekit_url"] as String,
      accessToken: json["access_token"] as String,
      channelId: json["channel_id"] as String,
      participantUserId: json["participant_user_id"] as String,
    );
  }
}

class ApiVoiceSession {
  const ApiVoiceSession({
    required this.channelId,
    required this.participantUserId,
    required this.isMuted,
  });

  final String channelId;
  final String participantUserId;
  final bool isMuted;

  factory ApiVoiceSession.fromJson(Map<String, dynamic> json) {
    return ApiVoiceSession(
      channelId: json["channel_id"] as String,
      participantUserId: json["participant_user_id"] as String,
      isMuted: json["is_muted"] as bool? ?? false,
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

class ApiUserLookup {
  const ApiUserLookup({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String? displayName;

  factory ApiUserLookup.fromJson(Map<String, dynamic> json) {
    return ApiUserLookup(
      id: json["id"] as String,
      displayName: json["display_name"] as String?,
    );
  }
}
