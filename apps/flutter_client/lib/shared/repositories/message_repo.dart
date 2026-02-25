import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class MessageRepo {
  Future<Result<List<Message>>> listMessages({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<Message>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
  });

  Future<Result<Message>> updateMessage({
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
}
