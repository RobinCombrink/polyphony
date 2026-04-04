import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/messages/bloc/pinned_messages_bloc.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final seeder = EntitySeeder();
  final fixture = seeder.chatApiFixture();

  final pinnedMessage1 = seeder.pinnedMessage(
    serverId: fixture.listedServer.id,
    channelId: fixture.listedChannel.id,
    messageId: const MessageId("msg-pinned-1"),
    pinnedByUserId: fixture.ownerUserId,
    authorUserId: fixture.ownerUserId,
    content: "first pinned",
  );

  final pinnedMessage2 = seeder.pinnedMessage(
    serverId: fixture.listedServer.id,
    channelId: fixture.listedChannel.id,
    messageId: const MessageId("msg-pinned-2"),
    pinnedByUserId: fixture.ownerUserId,
    authorUserId: fixture.ownerUserId,
    content: "second pinned",
  );

  group("load pinned messages", () {
    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "emits loading then loaded with pinned messages",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(
          pinnedMessages: [pinnedMessage1, pinnedMessage2],
        ),
      ),
      act: (bloc) => bloc.add(
        LoadPinnedMessagesRequested(serverId: fixture.listedServer.id),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesLoadingState>(),
        isA<PinnedMessagesLoadedState>()
            .having(
              (s) => s.pinnedMessages.length,
              "count",
              2,
            )
            .having(
              (s) => s.serverId,
              "serverId",
              fixture.listedServer.id,
            ),
      ],
    );

    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "emits loading then loaded with empty list when no pins exist",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(),
      ),
      act: (bloc) => bloc.add(
        LoadPinnedMessagesRequested(serverId: fixture.listedServer.id),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesLoadingState>(),
        isA<PinnedMessagesLoadedState>().having(
          (s) => s.pinnedMessages,
          "empty list",
          isEmpty,
        ),
      ],
    );

    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "emits exception state when loading fails",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(
          forceGetManyError: true,
        ),
      ),
      act: (bloc) => bloc.add(
        LoadPinnedMessagesRequested(serverId: fixture.listedServer.id),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesLoadingState>(),
        isA<PinnedMessagesExceptionState>().having(
          (s) => s.error.toString(),
          "error",
          contains("Failed to list pinned messages"),
        ),
      ],
    );
  });

  group("pin message", () {
    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "refreshes list after successful pin",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(),
      ),
      act: (bloc) => bloc.add(
        PinMessageRequested(
          serverId: fixture.listedServer.id,
          messageId: fixture.listedMessage.id,
        ),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesLoadingState>(),
        isA<PinnedMessagesLoadedState>(),
      ],
    );

    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "emits exception state when pin fails",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(
          forceCreateOneError: true,
        ),
      ),
      act: (bloc) => bloc.add(
        PinMessageRequested(
          serverId: fixture.listedServer.id,
          messageId: fixture.listedMessage.id,
        ),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesExceptionState>().having(
          (s) => s.error.toString(),
          "error",
          contains("Failed to pin message"),
        ),
      ],
    );
  });

  group("unpin message", () {
    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "refreshes list after successful unpin",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(
          pinnedMessages: [pinnedMessage1],
        ),
      ),
      act: (bloc) => bloc.add(
        UnpinMessageRequested(
          serverId: fixture.listedServer.id,
          messageId: pinnedMessage1.messageId,
        ),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesLoadingState>(),
        isA<PinnedMessagesLoadedState>().having(
          (s) => s.pinnedMessages,
          "empty after unpin",
          isEmpty,
        ),
      ],
    );

    blocTest<PinnedMessagesBloc, PinnedMessagesState>(
      "emits exception state when unpin fails",
      build: () => PinnedMessagesBloc(
        pinnedMessageRepo: FakePinnedMessageRepository(
          forceDeleteOneError: true,
        ),
      ),
      act: (bloc) => bloc.add(
        UnpinMessageRequested(
          serverId: fixture.listedServer.id,
          messageId: fixture.listedMessage.id,
        ),
      ),
      expect: () => <Matcher>[
        isA<PinnedMessagesExceptionState>().having(
          (s) => s.error.toString(),
          "error",
          contains("Failed to unpin message"),
        ),
      ],
    );
  });
}
