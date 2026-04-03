part of "friends_bloc.dart";

sealed class FriendsEvent {
  const FriendsEvent();
}

final class LoadFriendsRequested extends FriendsEvent {
  const LoadFriendsRequested();
}

final class BlockUserFromFriendsRequested extends FriendsEvent {
  const BlockUserFromFriendsRequested({required this.userId});

  final UserId userId;
}

final class UnblockUserRequested extends FriendsEvent {
  const UnblockUserRequested({required this.userId});

  final UserId userId;
}
