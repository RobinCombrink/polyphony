import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/friend_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_member_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "server_members_event.dart";
part "server_members_state.dart";

class ServerMembersBloc extends Bloc<ServerMembersEvent, ServerMembersState> {
  ServerMembersBloc({
    required ServerMemberRepo serverMemberRepo,
    required ProfileRepo profileRepo,
    required FriendRepo friendRepo,
  })  : _serverMemberRepo = serverMemberRepo,
        _profileRepo = profileRepo,
        _friendRepo = friendRepo,
        super(const ServerMembersInitialState()) {
    on<LoadServerMembersRequested>(_onLoadServerMembersRequested);
    on<ResetServerMembersRequested>(_onResetServerMembersRequested);
    on<SendFriendRequestToServerMemberRequested>(
      _onSendFriendRequestToServerMemberRequested,
    );
    on<CancelOutgoingFriendRequestRequested>(
      _onCancelOutgoingFriendRequestRequested,
    );
  }

  final ServerMemberRepo _serverMemberRepo;
  final ProfileRepo _profileRepo;
  final FriendRepo _friendRepo;

  void _onResetServerMembersRequested(
    ResetServerMembersRequested event,
    Emitter<ServerMembersState> emit,
  ) {
    emit(const ServerMembersInitialState());
  }

  Future<void> _onLoadServerMembersRequested(
    LoadServerMembersRequested event,
    Emitter<ServerMembersState> emit,
  ) async {
    final trimmedServerId = event.serverId.trim();
    final loadedState = _loadedStateOrNull(state);
    final existingMembers = switch (loadedState) {
      ServerMembersLoadedDataState(:final serverId, :final members)
          when serverId == trimmedServerId =>
        members,
      _ => const <UserProfile>[],
    };

    if (trimmedServerId.isEmpty) {
      emit(
        switch (state) {
          final ServerMembersLoadedDataState loadedState =>
            ServerMembersValidationFailedState(
              issue: ServerMembersValidationIssue.serverSelectionRequired,
              serverId: loadedState.serverId,
              members: loadedState.members,
              friendUserIds: loadedState.friendUserIds,
              pendingOutgoingFriendRequests:
                  loadedState.pendingOutgoingFriendRequests,
            ),
          _ => ServerMembersExceptionState(
              error: Exception(
                "Server must be selected before loading members.",
              ),
            ),
        },
      );
      return;
    }

    emit(const ServerMembersLoadingState());

    final membersResult = await _serverMemberRepo.getMany(
      query: GetServerMembersQuery(serverId: trimmedServerId),
    );

    switch (membersResult) {
      case Ok<Iterable<ServerMember>>(:final value):
        final members = await _resolveUserProfiles(
          members: value.toList(),
          existingMembers: existingMembers,
        );
        final friendUserIds = await _resolveFriendUserIds();
        final pendingOutgoingFriendRequests =
            await _resolvePendingOutgoingFriendRequests();
        emit(ServerMembersLoadedState(
          serverId: trimmedServerId,
          members: members,
          friendUserIds: friendUserIds,
          pendingOutgoingFriendRequests: pendingOutgoingFriendRequests,
        ));
      case Error<Iterable<ServerMember>>(:final error):
        emit(ServerMembersExceptionState(error: error));
    }
  }

  Future<void> _onSendFriendRequestToServerMemberRequested(
    SendFriendRequestToServerMemberRequested event,
    Emitter<ServerMembersState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);
    if (loadedState == null) {
      emit(ServerMembersExceptionState(
        error: Exception(
          "Server members must be loaded before sending a friend request.",
        ),
      ));
      return;
    }

    final trimmedServerId = event.serverId.trim();
    final trimmedTargetUserId = event.targetUserId.trim();

    if (trimmedServerId.isEmpty || trimmedServerId != loadedState.serverId) {
      emit(ServerMembersValidationFailedState(
        issue: ServerMembersValidationIssue.serverSelectionRequired,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    if (trimmedTargetUserId.isEmpty) {
      emit(ServerMembersValidationFailedState(
        issue: ServerMembersValidationIssue.targetUserRequired,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    if (!loadedState.members
        .any((member) => member.userId == trimmedTargetUserId)) {
      emit(ServerMembersValidationFailedState(
        issue: ServerMembersValidationIssue.serverMemberSelectionRequired,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    if (loadedState.friendUserIds.contains(trimmedTargetUserId)) {
      emit(ServerMembersValidationFailedState(
        issue: ServerMembersValidationIssue.alreadyFriend,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    if (loadedState.pendingOutgoingFriendRequests.any(
      (request) => request.addresseeUserId == trimmedTargetUserId,
    )) {
      emit(ServerMembersValidationFailedState(
        issue: ServerMembersValidationIssue.sendFriendRequestConflict,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    final sendResult = await _friendRepo.createOne(
      command: SendFriendRequestFromServerContextCommand(
        serverId: trimmedServerId,
        targetUserId: trimmedTargetUserId,
      ),
    );

    switch (sendResult) {
      case Ok<PendingFriendRequest>(:final value):
        emit(ServerMembersLoadedState(
          serverId: loadedState.serverId,
          members: loadedState.members,
          friendUserIds: loadedState.friendUserIds,
          pendingOutgoingFriendRequests: <PendingFriendRequest>[
            ...loadedState.pendingOutgoingFriendRequests,
            value,
          ],
        ));
      case Error<PendingFriendRequest>(:final error):
        final issue = _classifySendFriendRequestIssue(error);
        if (issue != null) {
          emit(ServerMembersValidationFailedState(
            issue: issue,
            serverId: loadedState.serverId,
            members: loadedState.members,
            friendUserIds: loadedState.friendUserIds,
            pendingOutgoingFriendRequests:
                loadedState.pendingOutgoingFriendRequests,
          ));
          return;
        }

        emit(ServerMembersExceptionState(error: error));
    }
  }

  Future<void> _onCancelOutgoingFriendRequestRequested(
    CancelOutgoingFriendRequestRequested event,
    Emitter<ServerMembersState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);
    if (loadedState == null) {
      emit(ServerMembersExceptionState(
        error: Exception(
          "Server members must be loaded before cancelling a friend request.",
        ),
      ));
      return;
    }

    final trimmedRequestId = event.friendRequestId.trim();
    if (trimmedRequestId.isEmpty) {
      emit(ServerMembersValidationFailedState(
        issue:
            ServerMembersValidationIssue.pendingFriendRequestSelectionRequired,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    if (!loadedState.pendingOutgoingFriendRequests
        .any((request) => request.id == trimmedRequestId)) {
      emit(ServerMembersValidationFailedState(
        issue:
            ServerMembersValidationIssue.pendingFriendRequestSelectionRequired,
        serverId: loadedState.serverId,
        members: loadedState.members,
        friendUserIds: loadedState.friendUserIds,
        pendingOutgoingFriendRequests:
            loadedState.pendingOutgoingFriendRequests,
      ));
      return;
    }

    final cancelResult = await _friendRepo.deleteOne(
      command: CancelOutgoingFriendRequestCommand(
        friendRequestId: trimmedRequestId,
      ),
    );

    switch (cancelResult) {
      case Ok<void>():
        emit(ServerMembersLoadedState(
          serverId: loadedState.serverId,
          members: loadedState.members,
          friendUserIds: loadedState.friendUserIds,
          pendingOutgoingFriendRequests: loadedState
              .pendingOutgoingFriendRequests
              .where((request) => request.id != trimmedRequestId)
              .toList(growable: false),
        ));
      case Error<void>(:final error):
        final issue = _classifyCancelFriendRequestIssue(error);
        if (issue != null) {
          emit(ServerMembersValidationFailedState(
            issue: issue,
            serverId: loadedState.serverId,
            members: loadedState.members,
            friendUserIds: loadedState.friendUserIds,
            pendingOutgoingFriendRequests:
                loadedState.pendingOutgoingFriendRequests,
          ));
          return;
        }

        emit(ServerMembersExceptionState(error: error));
    }
  }

  ServerMembersValidationIssue? _classifySendFriendRequestIssue(
      Exception error) {
    if (error is! ApiRequestException) {
      return null;
    }

    return switch (error.statusCode) {
      403 => ServerMembersValidationIssue.sendFriendRequestForbidden,
      404 => ServerMembersValidationIssue.sendFriendRequestNotFound,
      409 => ServerMembersValidationIssue.sendFriendRequestConflict,
      _ => null,
    };
  }

  ServerMembersValidationIssue? _classifyCancelFriendRequestIssue(
      Exception error) {
    if (error is! ApiRequestException) {
      return null;
    }

    return switch (error.statusCode) {
      403 => ServerMembersValidationIssue.cancelFriendRequestForbidden,
      404 => ServerMembersValidationIssue.cancelFriendRequestNotFound,
      409 => ServerMembersValidationIssue.cancelFriendRequestConflict,
      _ => null,
    };
  }

  Future<Set<String>> _resolveFriendUserIds() async {
    final friendsResult = await _friendRepo.getMany(
      query: const GetFriendsQuery(),
    );

    return switch (friendsResult) {
      Ok<Iterable<Friend>>(:final value) => value
          .map((friend) => friend.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet(),
      Error<Iterable<Friend>>() => <String>{},
    };
  }

  Future<List<PendingFriendRequest>>
      _resolvePendingOutgoingFriendRequests() async {
    final pendingRequestsResult = await _friendRepo.getOne(
      query: const GetOutgoingPendingFriendRequestsQuery(),
    );

    return switch (pendingRequestsResult) {
      Ok<Iterable<PendingFriendRequest>>(:final value) => value
          .where((request) => request.id.trim().isNotEmpty)
          .toList(growable: false),
      Error<Iterable<PendingFriendRequest>>() => const <PendingFriendRequest>[],
    };
  }

  Future<List<UserProfile>> _resolveUserProfiles({
    required List<ServerMember> members,
    required List<UserProfile> existingMembers,
  }) async {
    final uniqueUserIds = members
        .map((member) => member.userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList();
    final existingDisplayNamesByUserId = <String, String?>{
      for (final profile in existingMembers)
        profile.userId.trim(): profile.displayName?.trim(),
    };

    final resolvedProfiles = <UserProfile>[];

    for (final userId in uniqueUserIds) {
      if (existingDisplayNamesByUserId.containsKey(userId)) {
        resolvedProfiles.add(
          UserProfile(
            userId: userId,
            displayName: existingDisplayNamesByUserId[userId],
          ),
        );
        continue;
      }

      final userResult = await _profileRepo.getOne(
        query: GetUserQuery(userId: userId),
      );

      final profile = switch (userResult) {
        Ok<UserProfile>(:final value) => UserProfile(
            userId: value.userId,
            displayName: value.displayName,
          ),
        Error<UserProfile>() => UserProfile(
            userId: userId,
            displayName: null,
          ),
      };

      resolvedProfiles.add(profile);
    }

    return resolvedProfiles;
  }

  ServerMembersLoadedDataState? _loadedStateOrNull(ServerMembersState state) {
    return switch (state) {
      ServerMembersLoadedDataState() => state,
      _ => null,
    };
  }
}
