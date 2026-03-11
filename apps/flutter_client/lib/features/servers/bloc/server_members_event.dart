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

final class SendFriendRequestToServerMemberRequested
    extends ServerMembersEvent {
  const SendFriendRequestToServerMemberRequested({
    required this.serverId,
    required this.targetUserId,
  });

  final String serverId;
  final String targetUserId;
}

final class CancelOutgoingFriendRequestRequested extends ServerMembersEvent {
  const CancelOutgoingFriendRequestRequested({
    required this.friendRequestId,
  });

  final String friendRequestId;
}
