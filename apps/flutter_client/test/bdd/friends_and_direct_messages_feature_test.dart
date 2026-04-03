import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/direct_messages/bloc/direct_messages_bloc.dart";
import "package:polyphony_flutter_client/features/friends/bloc/friends_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/block_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/direct_message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/friend_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

void main() {
  group("Feature: Friends and direct messages", () {
    group("Rule: User can control social boundaries", () {
      blocTest<FriendsBloc, FriendsState>(
        "Scenario: User can block and unblock a friend",
        build: () {
          final blockRepo =
              _InMemoryBlockRepo(initialBlockedUserIds: const <UserId>{});
          return FriendsBloc(
            friendRepo: _StaticFriendRepo(),
            blockRepo: blockRepo,
          );
        },
        act: (bloc) => bloc
          ..add(const LoadFriendsRequested())
          ..add(const BlockUserFromFriendsRequested(userId: UserId("friend-2")))
          ..add(const UnblockUserRequested(userId: UserId("friend-2"))),
        expect: () => <Matcher>[
          isA<FriendsLoadingState>(),
          isA<FriendsLoadedState>(),
          isA<FriendsLoadedState>().having(
            (state) => state.blockedUserIds.contains(const UserId("friend-2")),
            "friend blocked",
            isTrue,
          ),
          isA<FriendsLoadedState>().having(
            (state) => state.blockedUserIds.contains(const UserId("friend-2")),
            "friend unblocked",
            isFalse,
          ),
        ],
      );

      blocTest<DirectMessagesBloc, DirectMessagesState>(
        "Scenario: Blocked relationship prevents sending a direct message",
        build: () => DirectMessagesBloc(
          directMessageRepo: _InMemoryDirectMessageRepo(),
          blockRepo: _InMemoryBlockRepo(
              initialBlockedUserIds: const <UserId>{UserId("friend-2")}),
          currentUserId: const UserId("user-1"),
        ),
        act: (bloc) => bloc
          ..add(const LoadDirectMessageThreadsRequested())
          ..add(const SelectDirectMessageThreadRequested(
              threadId: DirectMessageThreadId("thread-1")))
          ..add(const SendDirectMessageRequested(content: "hello")),
        expect: () => <Matcher>[
          isA<DirectMessagesLoadingState>(),
          isA<DirectMessagesLoadedState>(),
          isA<DirectMessagesLoadedState>(),
          isA<DirectMessagesValidationFailedState>().having(
            (state) => state.issue,
            "validation issue",
            DirectMessagesValidationIssue.blockedRelationship,
          ),
        ],
      );

      blocTest<DirectMessagesBloc, DirectMessagesState>(
        "Scenario: User can unblock then send direct message",
        build: () => DirectMessagesBloc(
          directMessageRepo: _InMemoryDirectMessageRepo(),
          blockRepo: _InMemoryBlockRepo(
              initialBlockedUserIds: const <UserId>{UserId("friend-2")}),
          currentUserId: const UserId("user-1"),
        ),
        act: (bloc) => bloc
          ..add(const LoadDirectMessageThreadsRequested())
          ..add(const SelectDirectMessageThreadRequested(
              threadId: DirectMessageThreadId("thread-1")))
          ..add(const UnblockSelectedDirectMessageUserRequested())
          ..add(const SendDirectMessageRequested(content: "hello")),
        expect: () => <Matcher>[
          isA<DirectMessagesLoadingState>(),
          isA<DirectMessagesLoadedState>(),
          isA<DirectMessagesLoadedState>(),
          isA<DirectMessagesLoadedState>().having(
            (state) => state.blockedUserIds.contains(const UserId("friend-2")),
            "friend removed from blocked list",
            isFalse,
          ),
          isA<DirectMessagesLoadedState>().having(
            (state) => state.selectedThreadMessages.length,
            "sent message count",
            1,
          ),
        ],
      );
    });
  });
}

final class _StaticFriendRepo implements FriendRepo {
  @override
  Future<Result<PendingFriendRequest>> createOne({
    required SendFriendRequestFromServerContextCommand command,
  }) async {
    return Ok<PendingFriendRequest>(
      PendingFriendRequest(
        id: FriendRequestId("pending-${command.targetUserId.value}"),
        requesterUserId: const UserId("user-1"),
        addresseeUserId: command.targetUserId,
      ),
    );
  }

  @override
  Future<Result<void>> deleteOne({
    required CancelOutgoingFriendRequestCommand command,
  }) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<Iterable<Friend>>> getMany(
      {required GetFriendsQuery query}) async {
    return const Ok<Iterable<Friend>>(<Friend>[
      Friend(userId: UserId("friend-1")),
      Friend(userId: UserId("friend-2")),
    ]);
  }

  @override
  Future<Result<Iterable<PendingFriendRequest>>> getOne({
    required GetOutgoingPendingFriendRequestsQuery query,
  }) async {
    return const Ok<Iterable<PendingFriendRequest>>(<PendingFriendRequest>[]);
  }
}

final class _InMemoryBlockRepo implements BlockRepo {
  _InMemoryBlockRepo({required Set<UserId> initialBlockedUserIds})
      : _blockedUserIds = <UserId>{...initialBlockedUserIds};

  final Set<UserId> _blockedUserIds;

  @override
  Future<Result<void>> createOne({required BlockUserCommand command}) async {
    _blockedUserIds.add(command.userId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> deleteOne({required UnblockUserCommand command}) async {
    _blockedUserIds.remove(command.userId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<Iterable<BlockedUser>>> getMany({
    required GetBlockedUsersQuery query,
  }) async {
    return Ok<Iterable<BlockedUser>>(
      _blockedUserIds
          .map((userId) => BlockedUser(userId: userId))
          .toList(growable: false),
    );
  }
}

final class _InMemoryDirectMessageRepo implements DirectMessageRepo {
  final _threads = const <DirectMessageThread>[
    DirectMessageThread(
      id: DirectMessageThreadId("thread-1"),
      participantAUserId: UserId("user-1"),
      participantBUserId: UserId("friend-2"),
    ),
  ];

  final _messages = <DirectMessage>[];

  @override
  Future<Result<DirectMessageThread>> createOne({
    required OpenOrGetDirectMessageThreadCommand command,
  }) async {
    final existing = _threads.where((thread) {
      return thread.participantAUserId == command.userId ||
          thread.participantBUserId == command.userId;
    }).first;

    return Ok<DirectMessageThread>(existing);
  }

  @override
  Future<Result<Iterable<DirectMessage>>> getOne({
    required GetDirectMessagesQuery query,
  }) async {
    return Ok<Iterable<DirectMessage>>(
      _messages
          .where((message) => message.threadId == query.threadId)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<Iterable<DirectMessageThread>>> getMany({
    required GetDirectMessageThreadsQuery query,
  }) async {
    return Ok<Iterable<DirectMessageThread>>(_threads);
  }

  @override
  Future<Result<DirectMessage>> updateOne({
    required SendDirectMessageCommand command,
  }) async {
    final message = DirectMessage(
      id: DirectMessageId("message-${_messages.length + 1}"),
      threadId: command.threadId,
      authorUserId: const UserId("user-1"),
      content: command.content,
    );
    _messages.add(message);

    return Ok<DirectMessage>(message);
  }

  @override
  Future<Result<Iterable<DirectMessage>>> updateMany({
    required SearchDirectMessagesForUserCommand command,
  }) async {
    return Ok<Iterable<DirectMessage>>(_messages);
  }
}
