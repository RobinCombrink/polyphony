import "package:flutter_bloc/flutter_bloc.dart";
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
        emit(ServerMembersLoadedState(
          serverId: trimmedServerId,
          members: members,
          friendUserIds: friendUserIds,
        ));
      case Error<Iterable<ServerMember>>(:final error):
        emit(ServerMembersExceptionState(error: error));
    }
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
