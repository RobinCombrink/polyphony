import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";

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
  });
}
