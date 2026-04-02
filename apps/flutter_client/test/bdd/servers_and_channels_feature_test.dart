import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

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
          isA<VoiceChannelSelected>().having(
            (state) => state.selectedVoiceChannel.id,
            "selected voice channel",
            fixture.listedVoiceChannel.id,
          ),
        ],
      );
    });

    group("Rule: Server owner can update a server name", () {
      blocTest<ServersBloc, ServersState>(
        "Scenario: Server owner can rename their server",
        build: () => ServersBloc(
          serverRepo: FakeServerRepository(fixture: fixture),
        ),
        act: (bloc) async {
          bloc.add(const LoadServersRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(SelectServerRequested(serverId: fixture.listedServer.id));
          await Future<void>.delayed(Duration.zero);
          bloc.add(UpdateServerNameRequested(
            serverId: fixture.listedServer.id,
            name: "Renamed Server",
          ));
        },
        expect: () => <Matcher>[
          isA<ServersLoadingState>(),
          isA<NoServerSelected>(),
          isA<ServerSelected>().having(
            (state) => state.selectedServer.id,
            "selected server id",
            fixture.listedServer.id,
          ),
          isA<ServersLoadingState>(),
          isA<ServerSelected>()
              .having(
                (state) => state.selectedServer.name,
                "updated server name",
                "Renamed Server",
              )
              .having(
                (state) => state.selectedServer.id,
                "server id preserved",
                fixture.listedServer.id,
              ),
        ],
      );

      blocTest<ServersBloc, ServersState>(
        "Scenario: Renaming with empty name fails validation",
        build: () => ServersBloc(
          serverRepo: FakeServerRepository(fixture: fixture),
        ),
        act: (bloc) async {
          bloc.add(const LoadServersRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(UpdateServerNameRequested(
            serverId: fixture.listedServer.id,
            name: "  ",
          ));
        },
        expect: () => <Matcher>[
          isA<ServersLoadingState>(),
          isA<NoServerSelected>(),
          isA<ServersValidationFailedState>().having(
            (state) => state.issue,
            "validation issue",
            ServersValidationIssue.serverNameRequired,
          ),
        ],
      );
    });

    group("Rule: Server owner can update a channel name", () {
      blocTest<ChannelsBloc, ChannelsState>(
        "Scenario: Server owner can rename a channel",
        build: () => ChannelsBloc(
          channelRepo: FakeChannelRepository(fixture: fixture),
        ),
        act: (bloc) async {
          bloc.add(LoadChannelsRequested(serverId: fixture.listedServer.id));
          await Future<void>.delayed(Duration.zero);
          bloc.add(UpdateChannelNameRequested(
            channelId: fixture.listedChannel.id,
            name: "renamed-channel",
          ));
        },
        expect: () => <Matcher>[
          isA<ChannelsLoadingState>(),
          isA<ChannelsLoadedState>(),
          isA<ChannelsLoadingState>(),
          isA<ChannelsLoadedState>().having(
            (state) => state.textChannels
                .any((channel) => channel.name == "renamed-channel"),
            "contains renamed channel",
            isTrue,
          ),
        ],
      );

      blocTest<ChannelsBloc, ChannelsState>(
        "Scenario: Renaming a channel with empty name fails validation",
        build: () => ChannelsBloc(
          channelRepo: FakeChannelRepository(fixture: fixture),
        ),
        act: (bloc) async {
          bloc.add(LoadChannelsRequested(serverId: fixture.listedServer.id));
          await Future<void>.delayed(Duration.zero);
          bloc.add(UpdateChannelNameRequested(
            channelId: fixture.listedChannel.id,
            name: "  ",
          ));
        },
        expect: () => <Matcher>[
          isA<ChannelsLoadingState>(),
          isA<ChannelsLoadedState>(),
          isA<ChannelsValidationFailedState>().having(
            (state) => state.issue,
            "validation issue",
            ChannelsValidationIssue.channelNameRequired,
          ),
        ],
      );
    });
  });
}
