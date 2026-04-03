import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<ChannelsBloc, ChannelsState>(
    "emits validation failed when server not selected",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc
        ..add(LoadChannelsRequested(
          serverId: fixture.listedServer.id,
        ))
        ..add(const CreateChannelRequested(
          serverId: ServerId(""),
          channelName: "channel",
          channelType: ChannelType.text,
        ));
    },
    expect: () => <Matcher>[
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>(),
      isA<ChannelsValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ChannelsValidationIssue.serverSelectionRequired,
      ),
    ],
  );

  blocTest<ChannelsBloc, ChannelsState>(
    "loads channels for selected server",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) => bloc.add(
      LoadChannelsRequested(
        serverId: fixture.listedServer.id,
      ),
    ),
    expect: () => <Matcher>[
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>()
          .having(
            (state) => state.textChannels.length,
            "text channels length",
            1,
          )
          .having(
            (state) => state.voiceChannels.length,
            "voice channels length",
            1,
          ),
    ],
  );

  blocTest<ChannelsBloc, ChannelsState>(
    "selects text channel from loaded state",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc
        ..add(LoadChannelsRequested(
          serverId: fixture.listedServer.id,
        ))
        ..add(SelectTextChannelRequested(channelId: fixture.listedChannel.id));
    },
    expect: () => <Matcher>[
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>(),
      isA<TextChannelSelected>().having(
        (state) => state.selectedTextChannel.id,
        "selected text channel",
        fixture.listedChannel.id,
      ),
    ],
  );

  blocTest<ChannelsBloc, ChannelsState>(
    "selects voice channel from loaded state",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc
        ..add(LoadChannelsRequested(
          serverId: fixture.listedServer.id,
        ))
        ..add(SelectVoiceChannelRequested(
          channelId: fixture.listedVoiceChannel.id,
        ));
    },
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

  blocTest<ChannelsBloc, ChannelsState>(
    "ignores channel selection before loaded",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) => bloc
        .add(SelectTextChannelRequested(channelId: fixture.listedChannel.id)),
    expect: () => <Matcher>[],
  );

  blocTest<ChannelsBloc, ChannelsState>(
    "deletes selected text channel",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc
        ..add(LoadChannelsRequested(
          serverId: fixture.listedServer.id,
        ))
        ..add(SelectTextChannelRequested(channelId: fixture.listedChannel.id))
        ..add(DeleteChannelRequested(channelId: fixture.listedChannel.id));
    },
    expect: () => <Matcher>[
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>(),
      isA<TextChannelSelected>(),
      isA<ChannelsLoadingState>(),
      isA<NoChannelSelected>()
          .having((state) => state.textChannels, "text channels", isEmpty)
          .having(
            (state) => state.voiceChannels.length,
            "voice channels length",
            1,
          ),
    ],
  );

  blocTest<ChannelsBloc, ChannelsState>(
    "restores previous server selection when returning to server",
    build: () => ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc
        ..add(LoadChannelsRequested(
          serverId: fixture.listedServer.id,
        ))
        ..add(SelectTextChannelRequested(channelId: fixture.listedChannel.id))
        ..add(LoadChannelsRequested(
          serverId: fixture.createdServer.id,
        ))
        ..add(LoadChannelsRequested(
          serverId: fixture.listedServer.id,
        ));
    },
    expect: () => <Matcher>[
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>(),
      isA<TextChannelSelected>().having(
        (state) => state.selectedTextChannel.id,
        "selected text channel",
        fixture.listedChannel.id,
      ),
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>()
          .having(
              (state) => state.serverId, "server id", fixture.createdServer.id)
          .having((state) => state, "no selected channel",
              isA<NoChannelSelected>()),
      isA<ChannelsLoadingState>(),
      isA<TextChannelSelected>()
          .having(
            (state) => state.serverId,
            "server id",
            fixture.listedServer.id,
          )
          .having(
            (state) => state.selectedTextChannel.id,
            "selected text channel",
            fixture.listedChannel.id,
          ),
    ],
  );
}
