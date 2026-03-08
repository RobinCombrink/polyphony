import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/server_member_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";

class ServerMemberRepository implements ServerMemberRepo {
  const ServerMemberRepository({required ServerService serverService})
      : _serverService = serverService;

  final ServerService _serverService;

  @override
  Future<Result<Iterable<ServerMember>>> getMany({
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
