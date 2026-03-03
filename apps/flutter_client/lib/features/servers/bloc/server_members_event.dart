part of "server_members_bloc.dart";

sealed class ServerMembersEvent {
  const ServerMembersEvent();
}

final class ResetServerMembersRequested extends ServerMembersEvent {
  const ResetServerMembersRequested();
}

final class LoadServerMembersRequested extends ServerMembersEvent {
  const LoadServerMembersRequested({
    required this.serverId,
  });

  final String serverId;
}
