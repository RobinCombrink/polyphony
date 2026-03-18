import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";

extension ApiServerToDomainExtension on ApiServer {
  Server toDomainModel() {
    return Server(
      id: id,
      name: name,
      ownerUserId: ownerUserId,
    );
  }
}

extension DomainServerToApiExtension on Server {
  ApiServer toApiModel() {
    return ApiServer(
      id: id,
      name: name,
      ownerUserId: ownerUserId,
    );
  }
}

extension ApiServerMemberToDomainExtension on ApiServerMember {
  ServerMember toDomainModel() {
    return ServerMember(
      serverId: serverId,
      userId: userId,
    );
  }
}

extension ApiFriendToDomainExtension on ApiFriend {
  Friend toDomainModel() {
    return Friend(
      userId: userId,
    );
  }
}

extension ApiFriendRequestToDomainExtension on ApiFriendRequest {
  PendingFriendRequest toDomainModel() {
    return PendingFriendRequest(
      id: id,
      requesterUserId: requesterUserId,
      addresseeUserId: addresseeUserId,
    );
  }
}

extension ApiBlockedUserToDomainExtension on ApiBlockedUser {
  BlockedUser toDomainModel() {
    return BlockedUser(userId: blockedUserId);
  }
}

extension ApiDirectMessageThreadToDomainExtension on ApiDirectMessageThread {
  DirectMessageThread toDomainModel() {
    return DirectMessageThread(
      id: id,
      participantAUserId: participantAUserId,
      participantBUserId: participantBUserId,
    );
  }
}

extension ApiDirectMessageToDomainExtension on ApiDirectMessage {
  DirectMessage toDomainModel() {
    return DirectMessage(
      id: id,
      threadId: threadId,
      authorUserId: authorUserId,
      content: content,
    );
  }
}

extension DomainFriendToApiExtension on Friend {
  ApiFriend toApiModel() {
    return ApiFriend(
      userId: userId,
    );
  }
}

extension DomainServerMemberToApiExtension on ServerMember {
  ApiServerMember toApiModel() {
    return ApiServerMember(
      serverId: serverId,
      userId: userId,
    );
  }
}

extension ApiChannelToDomainExtension on ApiChannel {
  Channel toDomainModel() {
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

extension DomainChannelToApiExtension on Channel {
  ApiChannel toApiModel() {
    return ApiChannel(
      id: id,
      serverId: serverId,
      name: name,
      channelType: channelType,
    );
  }
}

extension ApiMessageToDomainExtension on ApiMessage {
  Message toDomainModel() {
    return Message(
      id: id,
      channelId: channelId,
      authorUserId: authorUserId,
      content: content,
    );
  }
}

extension DomainMessageToApiExtension on Message {
  ApiMessage toApiModel() {
    return ApiMessage(
      id: id,
      channelId: channelId,
      authorUserId: authorUserId,
      content: content,
    );
  }
}

extension ApiVoiceConnectSessionToDomainExtension on ApiVoiceConnectSession {
  VoiceConnectSession toDomainModel() {
    return VoiceConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId,
      participantUserId: participantUserId,
    );
  }
}

extension DomainVoiceConnectSessionToApiExtension on VoiceConnectSession {
  ApiVoiceConnectSession toApiModel() {
    return ApiVoiceConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId,
      participantUserId: participantUserId,
    );
  }
}

extension ApiTextConnectSessionToDomainExtension on ApiTextConnectSession {
  TextConnectSession toDomainModel() {
    return TextConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId,
      participantUserId: participantUserId,
    );
  }
}

extension DomainTextConnectSessionToApiExtension on TextConnectSession {
  ApiTextConnectSession toApiModel() {
    return ApiTextConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId,
      participantUserId: participantUserId,
    );
  }
}

extension ApiMeToDomainExtension on ApiMe {
  UserProfile toDomainModel() {
    return UserProfile(
      userId: userId,
      displayName: displayName,
    );
  }
}

extension ApiUserLookupToDomainExtension on ApiUserLookup {
  UserProfile toDomainModel() {
    return UserProfile(
      userId: id,
      displayName: displayName,
    );
  }
}
