import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();
  const validUserId = "7f6f10d3-252e-4bb8-a8e8-f6524f239432";

  group("Feature: Servers and channels", () {
    group("Rule: User can browse and select available channels", () {
      blocTest<ChannelsBloc, ChannelsState>(
        "Scenario: User can load channels for selected server",
        build: () => ChannelsBloc(
          channelRepo: FakeChannelRepository(fixture: fixture),
        ),
        act: (bloc) => bloc.add(
          LoadChannelsRequested(serverId: fixture.listedServer.id),
        ),
        expect: () => <Matcher>[
          isA<ChannelsLoadingState>(),
          isA<ChannelsLoadedState>()
              .having((state) => state.textChannels.length, "text channels", 1)
              .having(
                  (state) => state.voiceChannels.length, "voice channels", 1),
        ],
      );

      blocTest<ChannelsBloc, ChannelsState>(
        "Scenario: User can select a voice channel in loaded server context",
        build: () => ChannelsBloc(
          channelRepo: FakeChannelRepository(fixture: fixture),
        ),
        act: (bloc) => bloc
          ..add(LoadChannelsRequested(serverId: fixture.listedServer.id))
          ..add(
            SelectVoiceChannelRequested(
                channelId: fixture.listedVoiceChannel.id),
          ),
        expect: () => <Matcher>[
          isA<ChannelsLoadingState>(),
          isA<ChannelsLoadedState>(),
          isA<ChannelsLoadedState>()
              .having((state) => state.selectedVoiceChannelId,
                  "selected voice channel", fixture.listedVoiceChannel.id)
              .having((state) => state.selectionMode, "selection mode",
                  ChannelSelectionMode.voice),
        ],
      );
    });

    group("Rule: Server membership changes require valid input", () {
      blocTest<ServersBloc, ServersState>(
        "Scenario: Adding a member with invalid user id fails validation",
        build: () => ServersBloc(
          serverRepo: FakeServerRepository(fixture: fixture),
        ),
        act: (bloc) => bloc
          ..add(const LoadServersRequested())
          ..add(SelectServerRequested(serverId: fixture.listedServer.id))
          ..add(
            AddServerMemberRequested(
              serverId: fixture.listedServer.id,
              userId: "auth0|invalid",
            ),
          ),
        expect: () => <Matcher>[
          isA<ServersLoadingState>(),
          isA<ServersLoadedState>(),
          isA<ServersLoadedState>(),
          isA<ServersValidationFailedState>().having((state) => state.issue,
              "issue", ServersValidationIssue.userIdInvalidFormat),
        ],
      );

      blocTest<ServersBloc, ServersState>(
        "Scenario: Adding a member forbidden by policy reports validation issue",
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
          ..add(
            AddServerMemberRequested(
              serverId: fixture.listedServer.id,
              userId: validUserId,
            ),
          ),
        expect: () => <Matcher>[
          isA<ServersLoadingState>(),
          isA<ServersLoadedState>(),
          isA<ServersLoadedState>(),
          isA<ServersLoadingState>(),
          isA<ServersValidationFailedState>().having((state) => state.issue,
              "issue", ServersValidationIssue.addMemberForbidden),
        ],
      );
    });
  });
}
