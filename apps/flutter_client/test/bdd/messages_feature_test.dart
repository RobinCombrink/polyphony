import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  group("Feature: Channel messages", () {
    group("Rule: Authenticated user manages messages in owned channels", () {
      blocTest<MessagesBloc, MessagesState>(
        "Scenario: Authenticated user can edit their message in a server channel",
        build: () => MessagesBloc(
          messageRepo: FakeMessageRepository(fixture: fixture),
          profileRepo: FakeProfileRepository(
            userId: fixture.ownerUserId,
            displayNamesByUserId: <UserId, String?>{
              fixture.listedMessage.authorUserId: "Listed Author",
            },
          ),
          textSessionRepo: FakeTextSessionRepository(fixture: fixture),
          messageRuntimeService: FakeMessageRuntimeService(),
        ),
        act: (bloc) => bloc
          ..add(LoadMessagesRequested(channelId: fixture.listedChannel.id))
          ..add(
            UpdateMessageRequested(
              channelId: fixture.listedChannel.id,
              messageId: fixture.listedMessage.id,
              messageContent: "edited",
            ),
          ),
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
        "Scenario: Updating a missing message reports that it does not exist",
        build: () => MessagesBloc(
          messageRepo: FakeMessageRepository(
            fixture: fixture,
            forceUpdateNotFound: true,
          ),
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
          textSessionRepo: FakeTextSessionRepository(fixture: fixture),
          messageRuntimeService: FakeMessageRuntimeService(),
        ),
        act: (bloc) => bloc
          ..add(LoadMessagesRequested(channelId: fixture.listedChannel.id))
          ..add(
            UpdateMessageRequested(
              channelId: fixture.listedChannel.id,
              messageId: fixture.listedMessage.id,
              messageContent: "edited",
            ),
          ),
        expect: () => <Matcher>[
          isA<MessagesLoadingState>(),
          isA<MessagesLoadedState>(),
          isA<MessagesLoadingState>(),
          isA<MessagesExceptionState>().having(
            (state) => state.error.toString(),
            "error",
            contains("Failed to update message: 404"),
          ),
        ],
      );

      blocTest<MessagesBloc, MessagesState>(
        "Scenario: Deleting a missing message reports that it does not exist",
        build: () => MessagesBloc(
          messageRepo: FakeMessageRepository(
            fixture: fixture,
            forceDeleteNotFound: true,
          ),
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
          textSessionRepo: FakeTextSessionRepository(fixture: fixture),
          messageRuntimeService: FakeMessageRuntimeService(),
        ),
        act: (bloc) => bloc
          ..add(LoadMessagesRequested(channelId: fixture.listedChannel.id))
          ..add(
            DeleteMessageRequested(
              channelId: fixture.listedChannel.id,
              messageId: fixture.listedMessage.id,
            ),
          ),
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
    });
  });
}
