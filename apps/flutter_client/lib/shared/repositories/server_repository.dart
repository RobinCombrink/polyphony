import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";

class ServerRepository implements ServerRepo {
  const ServerRepository({required ServerService serverService})
      : _serverService = serverService;

  final ServerService _serverService;

  @override
  Future<Result<List<Server>>> listServers({
    required String baseUrl,
  }) async {
    final serviceResult = await _serverService.listServers(baseUrl: baseUrl);

    return switch (serviceResult) {
      Ok<List<ApiServer>>(:final value) => Ok<List<Server>>(
          value.map((server) => server.toDomainModel()).toList()),
      Error<List<ApiServer>>(:final error) => Error<List<Server>>(error),
    };
  }

  @override
  Future<Result<Server>> createServer({
    required String baseUrl,
    required String name,
  }) async {
    final serviceResult = await _serverService.createServer(
      baseUrl: baseUrl,
      name: name,
    );

    return switch (serviceResult) {
      Ok<ApiServer>(:final value) => Ok<Server>(value.toDomainModel()),
      Error<ApiServer>(:final error) => Error<Server>(error),
    };
  }
}
