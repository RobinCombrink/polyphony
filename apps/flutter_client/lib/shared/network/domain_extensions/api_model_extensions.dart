import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";

extension ApiServerToDomainExtension on ApiServer {
  Server toDomainModel() {
    return Server(
      id: id,
      name: name,
      ownerSubject: ownerSubject,
    );
  }
}

extension DomainServerToApiExtension on Server {
  ApiServer toApiModel() {
    return ApiServer(
      id: id,
      name: name,
      ownerSubject: ownerSubject,
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
      authorSubject: authorSubject,
      content: content,
    );
  }
}

extension DomainMessageToApiExtension on Message {
  ApiMessage toApiModel() {
    return ApiMessage(
      id: id,
      channelId: channelId,
      authorSubject: authorSubject,
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
      participantSubject: participantSubject,
    );
  }
}

extension DomainVoiceConnectSessionToApiExtension on VoiceConnectSession {
  ApiVoiceConnectSession toApiModel() {
    return ApiVoiceConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId,
      participantSubject: participantSubject,
    );
  }
}
