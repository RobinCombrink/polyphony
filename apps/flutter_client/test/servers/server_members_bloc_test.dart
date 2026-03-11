import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

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
        friendUserIds: <String>{fixture.ownerUserId},
        initialPendingOutgoingRequests: <PendingFriendRequest>[
          const PendingFriendRequest(
            id: "pending-request-1",
            requesterUserId: "requester-user",
            addresseeUserId: "auth0|pending",
          ),
        ],
      ),
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
      friendRepo: FakeFriendRepository(friendUserIds: <String>{}),
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
      friendRepo: FakeFriendRepository(friendUserIds: <String>{}),
    ),
    seed: () => ServerMembersLoadedState(
      serverId: fixture.listedServer.id,
      members: <UserProfile>[
        UserProfile(userId: fixture.ownerUserId, displayName: "Owner"),
      ],
      friendUserIds: const <String>{},
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
        friendUserIds: <String>{},
        forceCreateError: true,
        createError: const ApiRequestException(
          operation: "send friend request from server context",
          statusCode: 409,
          responseBody: "",
        ),
      ),
    ),
    seed: () => ServerMembersLoadedState(
      serverId: fixture.listedServer.id,
      members: <UserProfile>[
        UserProfile(userId: fixture.ownerUserId, displayName: "Owner"),
      ],
      friendUserIds: const <String>{},
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
        friendUserIds: <String>{},
        initialPendingOutgoingRequests: <PendingFriendRequest>[
          const PendingFriendRequest(
            id: "pending-request-1",
            requesterUserId: "requester-user",
            addresseeUserId: "auth0|pending",
          ),
        ],
      ),
    ),
    seed: () => const ServerMembersLoadedState(
      serverId: "server-1",
      members: <UserProfile>[
        UserProfile(userId: "auth0|pending", displayName: "Pending User"),
      ],
      friendUserIds: <String>{},
      pendingOutgoingFriendRequests: <PendingFriendRequest>[
        PendingFriendRequest(
          id: "pending-request-1",
          requesterUserId: "requester-user",
          addresseeUserId: "auth0|pending",
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      const CancelOutgoingFriendRequestRequested(
        friendRequestId: "pending-request-1",
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
}
