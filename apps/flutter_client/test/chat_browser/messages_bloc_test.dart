import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<MessagesBloc, MessagesState>(
    "updates message and emits loaded state",
    build: () => MessagesBloc(
      messageRepo: FakeMessageRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc.add(LoadMessagesRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(UpdateMessageRequested(
        channelId: fixture.listedChannel.id,
        messageId: fixture.listedMessage.id,
        messageContent: "edited",
      ));
    },
    expect: () => <Matcher>[
      isA<MessagesLoadingState>(),
      isA<MessagesLoadedState>(),
      isA<MessagesLoadingState>(),
      isA<MessagesLoadedState>().having(
        (state) => state.messages.first.content,
        "updated content",
        "edited",
      ),
    ],
  );

  blocTest<MessagesBloc, MessagesState>(
    "emits exception state when delete fails",
    build: () => MessagesBloc(
      messageRepo: FakeMessageRepository(
        fixture: fixture,
        forceDeleteNotFound: true,
      ),
    ),
    act: (bloc) {
      bloc.add(LoadMessagesRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(DeleteMessageRequested(
        channelId: fixture.listedChannel.id,
        messageId: fixture.listedMessage.id,
      ));
    },
    expect: () => <Matcher>[
      isA<MessagesLoadingState>(),
      isA<MessagesLoadedState>(),
      isA<MessagesLoadingState>(),
      isA<MessagesExceptionState>().having(
        (state) => state.error.toString(),
        "error",
        contains("Failed to delete message: 404"),
      ),
    ],
  );
}
