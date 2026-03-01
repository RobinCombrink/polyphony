import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";

abstract interface class ChatApi {
  Future<Result<List<ApiServer>>> listServers({
    required String baseUrl,
  });

  Future<Result<ApiServer>> createServer({
    required String baseUrl,
    required String name,
  });

  Future<Result<void>> deleteServer({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<void>> addServerMember({
    required String baseUrl,
    required String serverId,
    required String userId,
  });

  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<List<ApiChannel>>> listChannels({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<ApiChannel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
    required ChannelType channelType,
  });

  Future<Result<void>> deleteChannel({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<List<ApiMessage>>> listMessages({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<ApiMessage>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
  });

  Future<Result<ApiMessage>> updateMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
    required String content,
  });

  Future<Result<void>> deleteMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
  });

  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<List<ApiVoiceSession>>> listVoiceSessions({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<void>> setSelfVoiceSessionMuted({
    required String baseUrl,
    required String channelId,
    required bool isMuted,
  });

  Future<Result<void>> disconnectVoiceSession({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<ApiMe>> getMe({
    required String baseUrl,
  });

  Future<Result<ApiMe>> updateDisplayName({
    required String baseUrl,
    required String displayName,
  });

  Future<Result<ApiUserLookup>> getUserById({
    required String baseUrl,
    required String userId,
  });
}
