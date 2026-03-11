part of "server_members_bloc.dart";

enum ServerMembersValidationIssue {
  serverSelectionRequired,
  serverMemberSelectionRequired,
  targetUserRequired,
  alreadyFriend,
  sendFriendRequestForbidden,
  sendFriendRequestNotFound,
  sendFriendRequestConflict,
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
    required this.friendUserIds,
  });

  final String serverId;
  final List<UserProfile> members;
  final Set<String> friendUserIds;
}

final class ServerMembersLoadedState extends ServerMembersLoadedDataState {
  const ServerMembersLoadedState({
    required super.serverId,
    required super.members,
    required super.friendUserIds,
  });
}

final class ServerMembersValidationFailedState
    extends ServerMembersLoadedDataState {
  const ServerMembersValidationFailedState({
    required this.issue,
    required super.serverId,
    required super.members,
    required super.friendUserIds,
  });

  final ServerMembersValidationIssue issue;
}

final class ServerMembersExceptionState extends ServerMembersState {
  const ServerMembersExceptionState({required this.error});

  final Exception error;
}
