import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class DirectMessageService {
  Future<Result<List<ApiDirectMessageThread>>> listThreads();

  Future<Result<ApiDirectMessageThread>> openOrGetThread({
    required String userId,
  });

  Future<Result<List<ApiDirectMessage>>> listMessages({
    required String threadId,
  });

  Future<Result<ApiDirectMessage>> sendMessage({
    required String threadId,
    required String content,
  });

  Future<Result<List<ApiDirectMessage>>> searchMessagesForUser({
    required String userId,
    required String query,
  });
}
