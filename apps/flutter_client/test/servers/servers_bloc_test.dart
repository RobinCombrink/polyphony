import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();
  const validUserId = "7f6f10d3-252e-4bb8-a8e8-f6524f239432";

  blocTest<ServersBloc, ServersState>(
    "loads servers and emits loaded state",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc.add(const LoadServersRequested()),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>().having(
        (state) => state.servers.length,
        "servers length",
        1,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed on empty server name",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(const CreateServerRequested(
        serverName: "   ",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.serverNameRequired,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "selects server from loaded state",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id)),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>().having(
        (state) => state.selectedServerId,
        "selected server id",
        fixture.listedServer.id,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "ignores selection before loaded",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) =>
        bloc.add(SelectServerRequested(serverId: fixture.listedServer.id)),
    expect: () => <Matcher>[],
  );

  blocTest<ServersBloc, ServersState>(
    "adds server member after server is selected",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(AddServerMemberRequested(
        serverId: fixture.listedServer.id,
        userId: validUserId,
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>().having(
        (state) => state.selectedServerId,
        "selected server id",
        fixture.listedServer.id,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "deletes selected server from context action",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(DeleteServerRequested(serverId: fixture.listedServer.id)),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>()
          .having((state) => state.servers, "servers", isEmpty)
          .having(
            (state) => state.selectedServerId,
            "selected server id",
            isNull,
          ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when add-member user id is empty",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(AddServerMemberRequested(
        serverId: fixture.listedServer.id,
        userId: "   ",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.userIdRequired,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when add-member user id is not a UUID",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(AddServerMemberRequested(
        serverId: fixture.listedServer.id,
        userId: "auth0|new_member",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.userIdInvalidFormat,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when add-member is forbidden",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(
        fixture: fixture,
        forceAddMemberError: true,
        addMemberError: const ApiRequestException(
          operation: "add server member",
          statusCode: 403,
          responseBody: "",
        ),
      ),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(AddServerMemberRequested(
        serverId: fixture.listedServer.id,
        userId: validUserId,
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.addMemberForbidden,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when add-member target is missing",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(
        fixture: fixture,
        forceAddMemberError: true,
        addMemberError: const ApiRequestException(
          operation: "add server member",
          statusCode: 404,
          responseBody: "",
        ),
      ),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(AddServerMemberRequested(
        serverId: fixture.listedServer.id,
        userId: validUserId,
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.addMemberTargetNotFound,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "invites friend to selected server",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(InviteFriendToServerRequested(
        serverId: fixture.listedServer.id,
        friendUserId: "auth0|friend-1",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>().having(
        (state) => state.selectedServerId,
        "selected server id",
        fixture.listedServer.id,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when invite-friend user id is empty",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(InviteFriendToServerRequested(
        serverId: fixture.listedServer.id,
        friendUserId: "   ",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.friendUserIdRequired,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when invite-friend is forbidden",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(
        fixture: fixture,
        forceInviteFriendError: true,
        inviteFriendError: const ApiRequestException(
          operation: "invite friend to server",
          statusCode: 403,
          responseBody: "",
        ),
      ),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(InviteFriendToServerRequested(
        serverId: fixture.listedServer.id,
        friendUserId: "auth0|friend-1",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.inviteFriendForbidden,
      ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "emits validation failed when invite-friend target is missing",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(
        fixture: fixture,
        forceInviteFriendError: true,
        inviteFriendError: const ApiRequestException(
          operation: "invite friend to server",
          statusCode: 404,
          responseBody: "",
        ),
      ),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(InviteFriendToServerRequested(
        serverId: fixture.listedServer.id,
        friendUserId: "auth0|friend-1",
      )),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadingState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.inviteFriendTargetNotFound,
      ),
    ],
  );
}
