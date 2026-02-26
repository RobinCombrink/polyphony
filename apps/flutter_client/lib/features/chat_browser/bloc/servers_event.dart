part of "servers_bloc.dart";

sealed class ServersEvent {
  const ServersEvent();
}

final class LoadServersRequested extends ServersEvent {
  const LoadServersRequested({required this.baseUrl});

  final String baseUrl;
}

final class CreateServerRequested extends ServersEvent {
  const CreateServerRequested({
    required this.baseUrl,
    required this.serverName,
  });

  final String baseUrl;
  final String serverName;
}

final class SelectServerRequested extends ServersEvent {
  const SelectServerRequested({required this.serverId});

  final String serverId;
}

final class AddServerMemberRequested extends ServersEvent {
  const AddServerMemberRequested({
    required this.baseUrl,
    required this.serverId,
    required this.userSubject,
  });

  final String baseUrl;
  final String serverId;
  final String userSubject;
}
