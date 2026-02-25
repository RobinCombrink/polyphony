import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ServerRepo {
  Future<Result<List<Server>>> listServers({
    required String baseUrl,
  });

  Future<Result<Server>> createServer({
    required String baseUrl,
    required String name,
  });
}
