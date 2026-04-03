part of "friends_bloc.dart";

enum FriendsValidationIssue {
  userSelectionRequired,
}

sealed class FriendsState {
  const FriendsState();
}

final class FriendsInitialState extends FriendsState {
  const FriendsInitialState();
}

final class FriendsLoadingState extends FriendsState {
  const FriendsLoadingState();
}

sealed class FriendsLoadedDataState extends FriendsState {
  const FriendsLoadedDataState({
    required this.friends,
    required this.blockedUserIds,
  });

  final List<Friend> friends;
  final Set<UserId> blockedUserIds;
}

final class FriendsLoadedState extends FriendsLoadedDataState {
  const FriendsLoadedState({
    required super.friends,
    required super.blockedUserIds,
  });
}

final class FriendsValidationFailedState extends FriendsLoadedDataState {
  const FriendsValidationFailedState({
    required this.issue,
    required super.friends,
    required super.blockedUserIds,
  });

  final FriendsValidationIssue issue;
}

final class FriendsExceptionState extends FriendsState {
  const FriendsExceptionState({required this.error});

  final Exception error;
}
