part of "servers_bloc.dart";

sealed class ServersEvent {
  const ServersEvent();
}

final class LoadServersRequested extends ServersEvent {
  const LoadServersRequested();
}

final class CreateServerRequested extends ServersEvent {
  const CreateServerRequested({
    required this.serverName,
  });

  final String serverName;
}

final class DeleteServerRequested extends ServersEvent {
  const DeleteServerRequested({required this.serverId});

  final String serverId;
}

final class SelectServerRequested extends ServersEvent {
  const SelectServerRequested({required this.serverId});

  final String serverId;
}

final class AddServerMemberRequested extends ServersEvent {
  const AddServerMemberRequested({
    required this.serverId,
    required this.userId,
  });

  final String serverId;
  final String userId;
}
