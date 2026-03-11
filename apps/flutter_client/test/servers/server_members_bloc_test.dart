import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<ServerMembersBloc, ServerMembersState>(
    "loads server users and marks known friends when friend repo is available",
    build: () => ServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo:
          FakeFriendRepository(friendUserIds: <String>{fixture.ownerUserId}),
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
              contains(fixture.ownerUserId)),
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
          .having((state) => state.friendUserIds, "friend user ids", isEmpty),
    ],
  );
}
