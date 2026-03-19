part of "servers_bloc.dart";

enum ServersValidationIssue {
  serverNameRequired,
  serverSelectionRequired,
}

sealed class ServersState {
  const ServersState();

  ServersLoadedState loadServers({
    required List<Server> servers,
  }) {
    return switch (this) {
      ServersInitialState() => NoServerSelected(servers: servers),
      ServersLoadingState() => NoServerSelected(servers: servers),
      NoServerSelected() => NoServerSelected(servers: servers),
      ServerSelected(:final selectedServer)
          when servers.any(
            (server) => server.id == selectedServer.id,
          ) =>
        ServerSelected(
          servers: servers,
          selectedServer: servers.firstWhere(
            (server) => server.id == selectedServer.id,
          ),
        ),
      ServerSelected() => NoServerSelected(servers: servers),
      ServersValidationFailedState(:final issue) =>
        ServersValidationFailedState(issue: issue, servers: servers),
      ServersExceptionState() => NoServerSelected(servers: servers),
    };
  }
}

final class ServersInitialState extends ServersState {
  const ServersInitialState();
}

final class ServersLoadingState extends ServersState {
  const ServersLoadingState();
}

sealed class ServersLoadedState extends ServersState {
  const ServersLoadedState({
    required this.servers,
  });

  final List<Server> servers;

  ServersLoadedState selectServer({
    Server? incomingSelectedServer,
  }) {
    if (incomingSelectedServer == null) {
      return NoServerSelected(servers: servers);
    }

    final selectedServer = servers.firstWhere(
      (server) => server.id == incomingSelectedServer.id,
      orElse: () => incomingSelectedServer,
    );

    if (!servers.any((server) => server.id == selectedServer.id)) {
      return NoServerSelected(servers: servers);
    }

    return ServerSelected(
      servers: servers,
      selectedServer: selectedServer,
    );
  }

  ServersLoadedState deleteServer({
    required List<Server> servers,
  }) {
    return switch (this) {
      NoServerSelected() => NoServerSelected(servers: servers),
      ServerSelected(:final selectedServer)
          when servers.contains(selectedServer) =>
        ServerSelected(
          servers: servers,
          selectedServer: selectedServer,
        ),
      ServerSelected() => NoServerSelected(servers: servers),
      ServersValidationFailedState(:final issue) =>
        ServersValidationFailedState(issue: issue, servers: servers),
    };
  }
}

final class NoServerSelected extends ServersLoadedState {
  const NoServerSelected({
    required super.servers,
  });
}

final class ServerSelected extends ServersLoadedState {
  const ServerSelected({
    required super.servers,
    required this.selectedServer,
  });

  final Server selectedServer;
}

final class ServersValidationFailedState extends ServersLoadedState {
  const ServersValidationFailedState({
    required this.issue,
    required super.servers,
  });

  final ServersValidationIssue issue;
}

final class ServersExceptionState extends ServersState {
  const ServersExceptionState({required this.error});

  final Exception error;
}
