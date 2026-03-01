import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

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
          serverId: "",
          channelName: "channel",
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
      isA<ChannelsLoadedState>().having(
        (state) => state.channels.length,
        "channels length",
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
      isA<ChannelsLoadedState>()
          .having(
            (state) => state.selectedTextChannelId,
            "selected text channel",
            fixture.listedChannel.id,
          )
          .having(
            (state) => state.selectionMode,
            "selection mode",
            ChannelSelectionMode.text,
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
        ..add(SelectVoiceChannelRequested(channelId: fixture.listedChannel.id));
    },
    expect: () => <Matcher>[
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>(),
      isA<ChannelsLoadedState>()
          .having(
            (state) => state.selectedVoiceChannelId,
            "selected voice channel",
            fixture.listedChannel.id,
          )
          .having(
            (state) => state.selectionMode,
            "selection mode",
            ChannelSelectionMode.voice,
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
      isA<ChannelsLoadedState>(),
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>()
          .having((state) => state.channels, "channels", isEmpty)
          .having(
            (state) => state.selectedTextChannelId,
            "selected text channel",
            isNull,
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
      isA<ChannelsLoadedState>()
          .having(
            (state) => state.selectedTextChannelId,
            "selected text channel",
            fixture.listedChannel.id,
          )
          .having(
            (state) => state.selectionMode,
            "selection mode",
            ChannelSelectionMode.text,
          ),
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>()
          .having(
              (state) => state.serverId, "server id", fixture.createdServer.id)
          .having((state) => state.selectedTextChannelId,
              "selected text channel", isNull),
      isA<ChannelsLoadingState>(),
      isA<ChannelsLoadedState>()
          .having(
            (state) => state.serverId,
            "server id",
            fixture.listedServer.id,
          )
          .having(
            (state) => state.selectedTextChannelId,
            "selected text channel",
            fixture.listedChannel.id,
          )
          .having(
            (state) => state.selectionMode,
            "selection mode",
            ChannelSelectionMode.text,
          ),
    ],
  );
}
