import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class MessageService {
  Future<Result<List<ApiMessage>>> listMessages({
    required String channelId,
  });

  Future<Result<ApiMessage>> createMessage({
    required String channelId,
    required String content,
    String? mentionedUserId,
  });

  Future<Result<ApiMessage>> updateMessage({
    required String channelId,
    required String messageId,
    required String content,
  });

  Future<Result<void>> deleteMessage({
    required String channelId,
    required String messageId,
  });

  Future<Result<List<ApiMessage>>> searchMessages({
    required String channelId,
    required String query,
  });
}
