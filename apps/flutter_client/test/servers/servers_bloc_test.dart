import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

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
        (state) => state,
        "state",
        isA<ServerSelected>().having(
          (selection) => selection.selectedServer,
          "selected server",
          fixture.listedServer,
        ),
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
            (state) => state,
            "state",
            isA<NoServerSelected>(),
          ),
    ],
  );

  blocTest<ServersBloc, ServersState>(
    "retains selected server across reload",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
      ..add(const LoadServersRequested())
      ..add(SelectServerRequested(serverId: fixture.listedServer.id))
      ..add(const LoadServersRequested()),
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>().having(
        (state) => state,
        "state",
        isA<ServerSelected>().having(
          (selection) => selection.selectedServer,
          "selected server",
          fixture.listedServer,
        ),
      ),
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>().having(
        (state) => state,
        "state",
        isA<ServerSelected>().having(
          (selection) => selection.selectedServer,
          "selected server",
          fixture.listedServer,
        ),
      ),
    ],
  );
}
