import "package:polyphony_flutter_client/shared/models/channel_type.dart";

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

class ServerMember {
  const ServerMember({
    required this.serverId,
    required this.userId,
  });

  final String serverId;
  final String userId;

  factory ServerMember.fromJson(Map<String, dynamic> json) {
    return ServerMember(
      serverId: json["server_id"] as String,
      userId: json["user_id"] as String,
    );
  }
}

sealed class Channel {
  const Channel({
    required this.id,
    required this.serverId,
    required this.name,
  });

  final String id;
  final String serverId;
  final String name;

  factory Channel.fromJson(Map<String, dynamic> json) {
    final id = json["id"] as String;
    final serverId = json["server_id"] as String;
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

class TextConnectSession {
  const TextConnectSession({
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
    required this.isSpeaking,
  });

  final String userId;
  final String displayName;
  final bool isMuted;
  final bool isSpeaking;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String? displayName;
}
