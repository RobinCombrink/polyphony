import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/block_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/friend_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "friends_event.dart";
part "friends_state.dart";

class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  FriendsBloc({
    required FriendRepo friendRepo,
    required BlockRepo blockRepo,
  })  : _friendRepo = friendRepo,
        _blockRepo = blockRepo,
        super(const FriendsInitialState()) {
    on<FriendsEvent>(_onEvent, transformer: sequential());
  }

  final FriendRepo _friendRepo;
  final BlockRepo _blockRepo;

  Future<void> _onEvent(
    FriendsEvent event,
    Emitter<FriendsState> emit,
  ) async {
    switch (event) {
      case LoadFriendsRequested():
        await _onLoadFriendsRequested(event, emit);
      case BlockUserFromFriendsRequested():
        await _onBlockUserFromFriendsRequested(event, emit);
      case UnblockUserRequested():
        await _onUnblockUserRequested(event, emit);
    }
  }

  Future<void> _onLoadFriendsRequested(
    LoadFriendsRequested event,
    Emitter<FriendsState> emit,
  ) async {
    emit(const FriendsLoadingState());

    final friendsResult =
        await _friendRepo.getMany(query: const GetFriendsQuery());
    final blockedUsersResult =
        await _blockRepo.getMany(query: const GetBlockedUsersQuery());

    switch ((friendsResult, blockedUsersResult)) {
      case (
          Ok<Iterable<Friend>>(value: final friendsValue),
          Ok<Iterable<BlockedUser>>(value: final blockedUsersValue)
        ):
        final friends = friendsValue.toList(growable: false);
        final blockedUserIds =
            blockedUsersValue.map((entry) => entry.userId).toSet();
        emit(FriendsLoadedState(
          friends: friends,
          blockedUserIds: blockedUserIds,
        ));
      case (Error<Iterable<Friend>>(:final error), _):
        emit(FriendsExceptionState(error: error));
      case (_, Error<Iterable<BlockedUser>>(:final error)):
        emit(FriendsExceptionState(error: error));
    }
  }

  Future<void> _onBlockUserFromFriendsRequested(
    BlockUserFromFriendsRequested event,
    Emitter<FriendsState> emit,
  ) async {
    final loadedState = switch (state) {
      final FriendsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(FriendsExceptionState(
        error: Exception("Friends must be loaded before blocking a user."),
      ));
      return;
    }

    final trimmedUserId = event.userId.trim();
    if (trimmedUserId.isEmpty) {
      emit(FriendsValidationFailedState(
        issue: FriendsValidationIssue.userSelectionRequired,
        friends: loadedState.friends,
        blockedUserIds: loadedState.blockedUserIds,
      ));
      return;
    }

    final blockResult = await _blockRepo.createOne(
      command: BlockUserCommand(userId: trimmedUserId),
    );

    switch (blockResult) {
      case Ok<void>():
        emit(FriendsLoadedState(
          friends: loadedState.friends,
          blockedUserIds: <String>{
            ...loadedState.blockedUserIds,
            trimmedUserId
          },
        ));
      case Error<void>(:final error):
        emit(FriendsExceptionState(error: error));
    }
  }

  Future<void> _onUnblockUserRequested(
    UnblockUserRequested event,
    Emitter<FriendsState> emit,
  ) async {
    final loadedState = switch (state) {
      final FriendsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(FriendsExceptionState(
        error: Exception("Friends must be loaded before unblocking a user."),
      ));
      return;
    }

    final trimmedUserId = event.userId.trim();
    if (trimmedUserId.isEmpty) {
      emit(FriendsValidationFailedState(
        issue: FriendsValidationIssue.userSelectionRequired,
        friends: loadedState.friends,
        blockedUserIds: loadedState.blockedUserIds,
      ));
      return;
    }

    final unblockResult = await _blockRepo.deleteOne(
      command: UnblockUserCommand(userId: trimmedUserId),
    );

    switch (unblockResult) {
      case Ok<void>():
        emit(FriendsLoadedState(
          friends: loadedState.friends,
          blockedUserIds: loadedState.blockedUserIds
              .where((userId) => userId != trimmedUserId)
              .toSet(),
        ));
      case Error<void>(:final error):
        emit(FriendsExceptionState(error: error));
    }
  }
}
