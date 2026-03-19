sealed class WorkspaceDestination {
  const WorkspaceDestination();
}

final class DirectMessageWorkspaceDestination extends WorkspaceDestination {
  const DirectMessageWorkspaceDestination();
}

sealed class ServerWorkspaceDestination extends WorkspaceDestination {
  const ServerWorkspaceDestination();
}

final class NoServerSelectedWorkspaceDestination
    extends ServerWorkspaceDestination {
  const NoServerSelectedWorkspaceDestination();
}

final class ServerSelectedWorkspaceDestination
    extends ServerWorkspaceDestination {
  const ServerSelectedWorkspaceDestination({required this.serverId});

  final String serverId;
}
