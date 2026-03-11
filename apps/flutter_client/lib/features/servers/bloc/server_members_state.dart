part of "server_members_bloc.dart";

enum ServerMembersValidationIssue {
  serverSelectionRequired,
  serverMemberSelectionRequired,
  pendingFriendRequestSelectionRequired,
  targetUserRequired,
  alreadyFriend,
  sendFriendRequestForbidden,
  sendFriendRequestNotFound,
  sendFriendRequestConflict,
  cancelFriendRequestForbidden,
  cancelFriendRequestNotFound,
  cancelFriendRequestConflict,
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
    required this.pendingOutgoingFriendRequests,
  });

  final String serverId;
  final List<UserProfile> members;
  final Set<String> friendUserIds;
  final List<PendingFriendRequest> pendingOutgoingFriendRequests;
}

final class ServerMembersLoadedState extends ServerMembersLoadedDataState {
  const ServerMembersLoadedState({
    required super.serverId,
    required super.members,
    required super.friendUserIds,
    required super.pendingOutgoingFriendRequests,
  });
}

final class ServerMembersValidationFailedState
    extends ServerMembersLoadedDataState {
  const ServerMembersValidationFailedState({
    required this.issue,
    required super.serverId,
    required super.members,
    required super.friendUserIds,
    required super.pendingOutgoingFriendRequests,
  });

  final ServerMembersValidationIssue issue;
}

final class ServerMembersExceptionState extends ServerMembersState {
  const ServerMembersExceptionState({required this.error});

  final Exception error;
}
