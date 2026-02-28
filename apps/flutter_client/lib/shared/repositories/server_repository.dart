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
  Future<Result<Iterable<Server>>> getMany({
    required GetServersQuery query,
  }) async {
    final serviceResult = await _serverService.listServers();

    return switch (serviceResult) {
      Ok<List<ApiServer>>(:final value) => Ok<Iterable<Server>>(
          value.map((server) => server.toDomainModel()).toList()),
      Error<List<ApiServer>>(:final error) => Error<Iterable<Server>>(error),
    };
  }

  @override
  Future<Result<Server>> createOne({
    required CreateServerCommand command,
  }) async {
    final serviceResult = await _serverService.createServer(
      name: command.name,
    );

    return switch (serviceResult) {
      Ok<ApiServer>(:final value) => Ok<Server>(value.toDomainModel()),
      Error<ApiServer>(:final error) => Error<Server>(error),
    };
  }

  @override
  Future<Result<void>> deleteOne({required DeleteServerCommand command}) {
    return _serverService.deleteServer(
      serverId: command.serverId,
    );
  }

  @override
  Future<Result<void>> updateOne({required AddServerMemberCommand command}) {
    return _serverService.addServerMember(
      serverId: command.serverId,
      userId: command.userId,
    );
  }

  @override
  Future<Result<Iterable<ServerMember>>> getServerMembers({
    required GetServerMembersQuery query,
  }) async {
    final serviceResult = await _serverService.listServerMembers(
      serverId: query.serverId,
    );

    return switch (serviceResult) {
      Ok<List<ApiServerMember>>(:final value) => Ok<Iterable<ServerMember>>(
          value.map((member) => member.toDomainModel()).toList(),
        ),
      Error<List<ApiServerMember>>(:final error) =>
        Error<Iterable<ServerMember>>(error),
    };
  }
}
