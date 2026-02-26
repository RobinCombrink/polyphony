import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<ServersBloc, ServersState>(
    "loads servers and emits loaded state",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) => bloc.add(
      const LoadServersRequested(baseUrl: "http://127.0.0.1:5067"),
    ),
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
    act: (bloc) {
      bloc.add(const LoadServersRequested(baseUrl: "http://127.0.0.1:5067"));
      bloc.add(const CreateServerRequested(
        baseUrl: "http://127.0.0.1:5067",
        serverName: "   ",
      ));
    },
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
    act: (bloc) {
      bloc.add(const LoadServersRequested(baseUrl: "http://127.0.0.1:5067"));
      bloc.add(SelectServerRequested(serverId: fixture.listedServer.id));
    },
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
    act: (bloc) {
      bloc.add(const LoadServersRequested(baseUrl: "http://127.0.0.1:5067"));
      bloc.add(SelectServerRequested(serverId: fixture.listedServer.id));
      bloc.add(AddServerMemberRequested(
        baseUrl: "http://127.0.0.1:5067",
        serverId: fixture.listedServer.id,
        userSubject: "auth0|new_member",
      ));
    },
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
    "emits validation failed when add-member subject is empty",
    build: () => ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc.add(const LoadServersRequested(baseUrl: "http://127.0.0.1:5067"));
      bloc.add(SelectServerRequested(serverId: fixture.listedServer.id));
      bloc.add(AddServerMemberRequested(
        baseUrl: "http://127.0.0.1:5067",
        serverId: fixture.listedServer.id,
        userSubject: "   ",
      ));
    },
    expect: () => <Matcher>[
      isA<ServersLoadingState>(),
      isA<ServersLoadedState>(),
      isA<ServersLoadedState>(),
      isA<ServersValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ServersValidationIssue.userSubjectRequired,
      ),
    ],
  );
}
