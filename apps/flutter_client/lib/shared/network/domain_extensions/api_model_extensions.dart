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

extension ApiChannelToDomainExtension on ApiChannel {
  Channel toDomainModel() {
    return Channel(
      id: id,
      serverId: serverId,
      name: name,
    );
  }
}

extension DomainChannelToApiExtension on Channel {
  ApiChannel toApiModel() {
    return ApiChannel(
      id: id,
      serverId: serverId,
      name: name,
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

extension ApiVoiceSessionToDomainExtension on ApiVoiceSession {
  VoiceSession toDomainModel() {
    return VoiceSession(
      channelId: channelId,
      participantUserId: participantUserId,
      isMuted: isMuted,
    );
  }
}

extension DomainVoiceSessionToApiExtension on VoiceSession {
  ApiVoiceSession toApiModel() {
    return ApiVoiceSession(
      channelId: channelId,
      participantUserId: participantUserId,
      isMuted: isMuted,
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
