import "package:polyphony_flutter_client/shared/models/channel_type.dart";

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

class ApiServerMember {
  const ApiServerMember({
    required this.serverId,
    required this.userId,
  });

  final String serverId;
  final String userId;

  factory ApiServerMember.fromJson(Map<String, dynamic> json) {
    return ApiServerMember(
      serverId: json["server_id"] as String,
      userId: json["user_id"] as String,
    );
  }
}

class ApiFriend {
  const ApiFriend({
    required this.userId,
  });

  final String userId;

  factory ApiFriend.fromJson(Map<String, dynamic> json) {
    return ApiFriend(
      userId: json["user_id"] as String,
    );
  }
}

class ApiFriendRequest {
  const ApiFriendRequest({
    required this.id,
    required this.requesterUserId,
    required this.addresseeUserId,
    required this.state,
  });

  final String id;
  final String requesterUserId;
  final String addresseeUserId;
  final String state;

  factory ApiFriendRequest.fromJson(Map<String, dynamic> json) {
    return ApiFriendRequest(
      id: json["id"] as String,
      requesterUserId: json["requester_user_id"] as String,
      addresseeUserId: json["addressee_user_id"] as String,
      state: json["state"] as String,
    );
  }
}

class ApiChannel {
  const ApiChannel({
    required this.id,
    required this.serverId,
    required this.name,
    this.channelType = ChannelType.text,
  });

  final String id;
  final String serverId;
  final String name;
  final ChannelType channelType;

  factory ApiChannel.fromJson(Map<String, dynamic> json) {
    return ApiChannel(
      id: json["id"] as String,
      serverId: json["server_id"] as String,
      name: json["name"] as String,
      channelType: ChannelType.fromApiValue(json["channel_type"] as String?),
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
    final payload = _messagePayload(json);

    return ApiMessage(
      id: _requiredString(payload, "id"),
      channelId: _requiredString(payload, "channel_id"),
      authorUserId: _requiredString(payload, "author_user_id"),
      content: _requiredString(payload, "content"),
    );
  }

  static Map<String, dynamic> _messagePayload(Map<String, dynamic> json) {
    final details = json["details"];
    final common = details is Map<dynamic, dynamic> ? details["common"] : null;

    return switch (common) {
      Map<dynamic, dynamic>() => Map<String, dynamic>.from(common),
      _ => throw const FormatException("Invalid message payload"),
    };
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final rawValue = json[key];
    if (rawValue is! String) {
      throw const FormatException("Invalid message payload");
    }

    return rawValue;
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

class ApiTextConnectSession {
  const ApiTextConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantUserId,
  });

  final String livekitUrl;
  final String accessToken;
  final String channelId;
  final String participantUserId;

  factory ApiTextConnectSession.fromJson(Map<String, dynamic> json) {
    return ApiTextConnectSession(
      livekitUrl: json["livekit_url"] as String,
      accessToken: json["access_token"] as String,
      channelId: json["channel_id"] as String,
      participantUserId: json["participant_user_id"] as String,
    );
  }
}

class ApiMe {
  const ApiMe({
    required this.userId,
    required this.displayName,
    required this.issuer,
  });

  final String userId;
  final String? displayName;
  final String issuer;

  factory ApiMe.fromJson(Map<String, dynamic> json) {
    return ApiMe(
      userId: json["user_id"] as String,
      displayName: json["display_name"] as String?,
      issuer: json["issuer"] as String,
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

class ApiNotificationUnreadCount {
  const ApiNotificationUnreadCount({
    required this.totalUnreadCount,
  });

  final int totalUnreadCount;

  factory ApiNotificationUnreadCount.fromJson(Map<String, dynamic> json) {
    final unreadValue = json["total_unread_count"];
    final totalUnreadCount = switch (unreadValue) {
      int() => unreadValue,
      _ => 0,
    };

    return ApiNotificationUnreadCount(
      totalUnreadCount: totalUnreadCount,
    );
  }
}

enum ApiNotificationMuteState {
  unmuted,
  muted;

  static ApiNotificationMuteState fromApiValue(String value) {
    return switch (value) {
      "muted" => ApiNotificationMuteState.muted,
      _ => ApiNotificationMuteState.unmuted,
    };
  }

  String get apiValue {
    return switch (this) {
      ApiNotificationMuteState.unmuted => "unmuted",
      ApiNotificationMuteState.muted => "muted",
    };
  }
}

enum ApiNotificationCategoryPreference {
  allMessages,
  onlyMentions,
  none;

  static ApiNotificationCategoryPreference fromApiValue(String value) {
    return switch (value) {
      "all_messages" => ApiNotificationCategoryPreference.allMessages,
      "none" => ApiNotificationCategoryPreference.none,
      _ => ApiNotificationCategoryPreference.onlyMentions,
    };
  }

  String get apiValue {
    return switch (this) {
      ApiNotificationCategoryPreference.allMessages => "all_messages",
      ApiNotificationCategoryPreference.onlyMentions => "only_mentions",
      ApiNotificationCategoryPreference.none => "none",
    };
  }
}

class ApiNotificationGlobalPreference {
  const ApiNotificationGlobalPreference({
    required this.muteState,
    required this.notificationCategory,
    required this.channelDefaultCategory,
  });

  final ApiNotificationMuteState muteState;
  final ApiNotificationCategoryPreference notificationCategory;
  final ApiNotificationCategoryPreference channelDefaultCategory;

  factory ApiNotificationGlobalPreference.fromJson(Map<String, dynamic> json) {
    return ApiNotificationGlobalPreference(
      muteState: ApiNotificationMuteState.fromApiValue(
        json["mute_state"] as String? ?? "unmuted",
      ),
      notificationCategory: ApiNotificationCategoryPreference.fromApiValue(
        json["notification_category"] as String? ?? "only_mentions",
      ),
      channelDefaultCategory: ApiNotificationCategoryPreference.fromApiValue(
        json["channel_default_category"] as String? ?? "only_mentions",
      ),
    );
  }
}

class ApiNotificationServerPreference {
  const ApiNotificationServerPreference({
    required this.muteState,
    required this.notificationCategory,
  });

  final ApiNotificationMuteState muteState;
  final ApiNotificationCategoryPreference notificationCategory;

  factory ApiNotificationServerPreference.fromJson(Map<String, dynamic> json) {
    return ApiNotificationServerPreference(
      muteState: ApiNotificationMuteState.fromApiValue(
        json["mute_state"] as String? ?? "unmuted",
      ),
      notificationCategory: ApiNotificationCategoryPreference.fromApiValue(
        json["notification_category"] as String? ?? "only_mentions",
      ),
    );
  }
}

class ApiNotificationChannelPreference {
  const ApiNotificationChannelPreference({
    required this.muteState,
    required this.mutedUntilEpochSeconds,
    required this.notificationCategory,
    required this.inheritedFromGlobalDefault,
  });

  final ApiNotificationMuteState muteState;
  final int? mutedUntilEpochSeconds;
  final ApiNotificationCategoryPreference notificationCategory;
  final bool inheritedFromGlobalDefault;

  factory ApiNotificationChannelPreference.fromJson(Map<String, dynamic> json) {
    return ApiNotificationChannelPreference(
      muteState: ApiNotificationMuteState.fromApiValue(
        json["mute_state"] as String? ?? "unmuted",
      ),
      mutedUntilEpochSeconds: json["muted_until_epoch_seconds"] as int?,
      notificationCategory: ApiNotificationCategoryPreference.fromApiValue(
        json["notification_category"] as String? ?? "only_mentions",
      ),
      inheritedFromGlobalDefault: json["inherited_from_global_default"] == true,
    );
  }
}
