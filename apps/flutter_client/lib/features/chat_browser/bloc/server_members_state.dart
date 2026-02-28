part of "server_members_bloc.dart";

enum ServerMembersValidationIssue {
  serverSelectionRequired,
}

sealed class ServerMembersState {
  const ServerMembersState();
}

final class ServerMembersInitialState extends ServerMembersState {
  const ServerMembersInitialState();
}

final class ServerMembersLoadingState extends ServerMembersState {
  const ServerMembersLoadingState();
}

sealed class ServerMembersLoadedDataState extends ServerMembersState {
  const ServerMembersLoadedDataState({
    required this.serverId,
    required this.members,
  });

  final String serverId;
  final List<UserProfile> members;
}

final class ServerMembersLoadedState extends ServerMembersLoadedDataState {
  const ServerMembersLoadedState({
    required super.serverId,
    required super.members,
  });
}

final class ServerMembersValidationFailedState
    extends ServerMembersLoadedDataState {
  const ServerMembersValidationFailedState({
    required this.issue,
    required super.serverId,
    required super.members,
  });

  final ServerMembersValidationIssue issue;
}

final class ServerMembersExceptionState extends ServerMembersState {
  const ServerMembersExceptionState({required this.error});

  final Exception error;
}
