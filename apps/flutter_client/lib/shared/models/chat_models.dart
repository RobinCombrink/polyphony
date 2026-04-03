import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

class Server {
  const Server(
      {required this.id, required this.name, required this.ownerUserId});

  final ServerId id;
  final String name;
  final UserId ownerUserId;

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: ServerId(json["id"] as String),
      name: json["name"] as String,
      ownerUserId: UserId(json["owner_user_id"] as String),
    );
  }
}

class ServerMember {
  const ServerMember({
    required this.serverId,
    required this.userId,
  });

  final ServerId serverId;
  final UserId userId;

  factory ServerMember.fromJson(Map<String, dynamic> json) {
    return ServerMember(
      serverId: ServerId(json["server_id"] as String),
      userId: UserId(json["user_id"] as String),
    );
  }
}

class Friend {
  const Friend({
    required this.userId,
  });

  final UserId userId;

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: UserId(json["user_id"] as String),
    );
  }
}

class PendingFriendRequest {
  const PendingFriendRequest({
    required this.id,
    required this.requesterUserId,
    required this.addresseeUserId,
  });

  final FriendRequestId id;
  final UserId requesterUserId;
  final UserId addresseeUserId;
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
  });

  final UserId userId;
}

class DirectMessageThread {
  const DirectMessageThread({
    required this.id,
    required this.participantAUserId,
    required this.participantBUserId,
  });

  final DirectMessageThreadId id;
  final UserId participantAUserId;
  final UserId participantBUserId;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.threadId,
    required this.authorUserId,
    required this.content,
  });

  final DirectMessageId id;
  final DirectMessageThreadId threadId;
  final UserId authorUserId;
  final String content;
}

sealed class Channel {
  const Channel({
    required this.id,
    required this.serverId,
    required this.name,
  });

  final ChannelId id;
  final ServerId serverId;
  final String name;

  factory Channel.fromJson(Map<String, dynamic> json) {
    final id = ChannelId(json["id"] as String);
    final serverId = ServerId(json["server_id"] as String);
    final name = json["name"] as String;
    final channelType =
        ChannelType.fromApiValue(json["channel_type"] as String?);

    return switch (channelType) {
      ChannelType.voice => VoiceChannel(
          id: id,
          serverId: serverId,
          name: name,
        ),
      ChannelType.text => TextChannel(
          id: id,
          serverId: serverId,
          name: name,
        ),
    };
  }
}

extension ChannelTypeExtension on Channel {
  ChannelType get channelType {
    return switch (this) {
      VoiceChannel() => ChannelType.voice,
      TextChannel() => ChannelType.text,
    };
  }
}

final class TextChannel extends Channel {
  const TextChannel({
    required super.id,
    required super.serverId,
    required super.name,
  });
}

final class VoiceChannel extends Channel {
  const VoiceChannel({
    required super.id,
    required super.serverId,
    required super.name,
  });
}

class Message {
  const Message({
    required this.id,
    required this.channelId,
    required this.authorUserId,
    required this.content,
  });

  final MessageId id;
  final ChannelId channelId;
  final UserId authorUserId;
  final String content;

  factory Message.fromJson(Map<String, dynamic> json) {
    final payload = _messagePayload(json);

    return Message(
      id: MessageId(_requiredString(payload, "id")),
      channelId: ChannelId(_requiredString(payload, "channel_id")),
      authorUserId: UserId(_requiredString(payload, "author_user_id")),
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

class VoiceConnectSession {
  const VoiceConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantUserId,
  });

  final String livekitUrl;
  final String accessToken;
  final ChannelId channelId;
  final UserId participantUserId;
}

class TextConnectSession {
  const TextConnectSession({
    required this.livekitUrl,
    required this.accessToken,
    required this.channelId,
    required this.participantUserId,
  });

  final String livekitUrl;
  final String accessToken;
  final ChannelId channelId;
  final UserId participantUserId;
}

class VoiceParticipant {
  const VoiceParticipant({
    required this.userId,
    required this.displayName,
    required this.isMuted,
    required this.isDeafened,
    required this.isSpeaking,
  });

  final UserId userId;
  final String displayName;
  final bool isMuted;
  final bool isDeafened;
  final bool isSpeaking;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
  });

  final UserId userId;
  final String? displayName;
}
