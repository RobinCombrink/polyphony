import "package:polyphony_flutter_client/shared/result/result.dart";

class RuntimeTextMessage {
  const RuntimeTextMessage({
    required this.channelId,
    required this.authorUserId,
    required this.content,
  });

  final String channelId;
  final String authorUserId;
  final String content;
}

abstract interface class MessageRuntimeService {
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  });

  Future<Result<void>> disconnect();

  Stream<RuntimeTextMessage> textMessages();

  Future<Result<void>> sendTextMessage({
    required String channelId,
    required String content,
  });
}
