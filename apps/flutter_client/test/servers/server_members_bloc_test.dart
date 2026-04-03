import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<ServerMembersBloc, ServerMembersState>(
    "loads server users with known friends and pending outgoing requests",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(
        friendUserIds: <UserId>{fixture.ownerUserId},
        initialPendingOutgoingRequests: <PendingFriendRequest>[
          const PendingFriendRequest(
            id: FriendRequestId("pending-request-1"),
            requesterUserId: UserId("requester-user"),
            addresseeUserId: UserId("auth0|pending"),
          ),
        ],
      ),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc.add(
      LoadServerMembersRequested(serverId: fixture.listedServer.id),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersLoadingState>(),
      isA<ServerMembersLoadedState>()
          .having(
              (state) => state.serverId, "server id", fixture.listedServer.id)
          .having((state) => state.friendUserIds, "friend user ids",
              contains(fixture.ownerUserId))
          .having(
            (state) => state.pendingOutgoingFriendRequests.length,
            "pending outgoing friend requests",
            1,
          ),
    ],
  );

  blocTest<ServerMembersBloc, ServerMembersState>(
    "loads server users with empty friend set when no friends are returned",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc.add(
      LoadServerMembersRequested(serverId: fixture.listedServer.id),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersLoadingState>(),
      isA<ServerMembersLoadedState>()
          .having(
              (state) => state.serverId, "server id", fixture.listedServer.id)
          .having((state) => state.friendUserIds, "friend user ids", isEmpty)
          .having(
            (state) => state.pendingOutgoingFriendRequests,
            "pending outgoing friend requests",
            isEmpty,
          ),
    ],
  );

  blocTest<ServerMembersBloc, ServerMembersState>(
    "sends friend request to server member and adds pending request",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    seed: () => ServerMembersLoadedState(
      serverId: fixture.listedServer.id,
      members: <UserProfile>[
        UserProfile(userId: fixture.ownerUserId, displayName: "Owner"),
      ],
      friendUserIds: const <UserId>{},
      pendingOutgoingFriendRequests: const <PendingFriendRequest>[],
    ),
    act: (bloc) => bloc.add(
      SendFriendRequestToServerMemberRequested(
        serverId: fixture.listedServer.id,
        targetUserId: fixture.ownerUserId,
      ),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersLoadedState>().having(
        (state) => state.pendingOutgoingFriendRequests
            .map((request) => request.addresseeUserId),
        "pending outgoing friend request addressees",
        contains(fixture.ownerUserId),
      ),
    ],
  );

  blocTest<ServerMembersBloc, ServerMembersState>(
    "emits validation failed when add-friend request conflicts",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(
        friendUserIds: <UserId>{},
        forceCreateError: true,
        createError: const ApiRequestException(
          operation: "send friend request from server context",
          statusCode: 409,
          responseBody: "",
        ),
      ),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    seed: () => ServerMembersLoadedState(
      serverId: fixture.listedServer.id,
      members: <UserProfile>[
        UserProfile(userId: fixture.ownerUserId, displayName: "Owner"),
      ],
      friendUserIds: const <UserId>{},
      pendingOutgoingFriendRequests: const <PendingFriendRequest>[],
    ),
    act: (bloc) => bloc.add(
      SendFriendRequestToServerMemberRequested(
        serverId: fixture.listedServer.id,
        targetUserId: fixture.ownerUserId,
      ),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersValidationFailedState>().having(
        (state) => state.issue,
        "validation issue",
        ServerMembersValidationIssue.sendFriendRequestConflict,
      ),
    ],
  );

  blocTest<ServerMembersBloc, ServerMembersState>(
    "cancels pending outgoing friend request",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(
        friendUserIds: <UserId>{},
        initialPendingOutgoingRequests: <PendingFriendRequest>[
          const PendingFriendRequest(
            id: FriendRequestId("pending-request-1"),
            requesterUserId: UserId("requester-user"),
            addresseeUserId: UserId("auth0|pending"),
          ),
        ],
      ),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    seed: () => const ServerMembersLoadedState(
      serverId: ServerId("server-1"),
      members: <UserProfile>[
        UserProfile(
            userId: UserId("auth0|pending"), displayName: "Pending User"),
      ],
      friendUserIds: <UserId>{},
      pendingOutgoingFriendRequests: <PendingFriendRequest>[
        PendingFriendRequest(
          id: FriendRequestId("pending-request-1"),
          requesterUserId: UserId("requester-user"),
          addresseeUserId: UserId("auth0|pending"),
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const CancelOutgoingFriendRequestRequested(
        friendRequestId: FriendRequestId("pending-request-1"),
      ),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersLoadedState>().having(
        (state) => state.pendingOutgoingFriendRequests,
        "pending outgoing friend requests",
        isEmpty,
      ),
    ],
  );

  blocTest<ServerMembersBloc, ServerMembersState>(
    "emits validation failed when outgoing request already exists for member",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    seed: () => ServerMembersLoadedState(
      serverId: fixture.listedServer.id,
      members: <UserProfile>[
        UserProfile(userId: fixture.ownerUserId, displayName: "Owner"),
      ],
      friendUserIds: const <UserId>{},
      pendingOutgoingFriendRequests: <PendingFriendRequest>[
        PendingFriendRequest(
          id: const FriendRequestId("pending-request-owner"),
          requesterUserId: const UserId("requester-user"),
          addresseeUserId: fixture.ownerUserId,
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      SendFriendRequestToServerMemberRequested(
        serverId: fixture.listedServer.id,
        targetUserId: fixture.ownerUserId,
      ),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersValidationFailedState>().having(
        (state) => state.issue,
        "validation issue",
        ServerMembersValidationIssue.sendFriendRequestConflict,
      ),
    ],
  );

  blocTest<ServerMembersBloc, ServerMembersState>(
    "emits validation failed when cancel pending request is not found",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(
        friendUserIds: <UserId>{},
        forceCancelError: true,
        cancelError: const ApiRequestException(
          operation: "cancel outgoing friend request",
          statusCode: 404,
          responseBody: "",
        ),
      ),
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    seed: () => const ServerMembersLoadedState(
      serverId: ServerId("server-1"),
      members: <UserProfile>[
        UserProfile(
            userId: UserId("auth0|pending"), displayName: "Pending User"),
      ],
      friendUserIds: <UserId>{},
      pendingOutgoingFriendRequests: <PendingFriendRequest>[
        PendingFriendRequest(
          id: FriendRequestId("pending-request-1"),
          requesterUserId: UserId("requester-user"),
          addresseeUserId: UserId("auth0|pending"),
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const CancelOutgoingFriendRequestRequested(
        friendRequestId: FriendRequestId("pending-request-1"),
      ),
    ),
    expect: () => <Matcher>[
      isA<ServerMembersValidationFailedState>().having(
        (state) => state.issue,
        "validation issue",
        ServerMembersValidationIssue.cancelFriendRequestNotFound,
      ),
    ],
  );
}
