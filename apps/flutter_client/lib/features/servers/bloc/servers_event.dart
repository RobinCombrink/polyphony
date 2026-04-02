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

final class UpdateServerNameRequested extends ServersEvent {
  const UpdateServerNameRequested({
    required this.serverId,
    required this.name,
  });

  final String serverId;
  final String name;
}

final class SelectServerRequested extends ServersEvent {
  const SelectServerRequested({required this.serverId});

  final String serverId;
}
