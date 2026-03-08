import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

class _CountingProfileRepository extends FakeProfileRepository {
  _CountingProfileRepository({
    required super.userId,
    super.displayNamesByUserId,
  });

  var getOneCalls = 0;

  @override
  Future<Result<UserProfile>> getOne({
    required GetUserQuery query,
  }) {
    getOneCalls += 1;
    return super.getOne(query: query);
  }
}

void main() {
  final fixture = EntitySeeder().chatApiFixture();
  late _CountingProfileRepository countingProfileRepository;

  blocTest<MessagesBloc, MessagesState>(
    "reuses author profiles between load and update",
    build: () {
      countingProfileRepository = _CountingProfileRepository(
        userId: fixture.ownerUserId,
        displayNamesByUserId: <String, String?>{
          fixture.listedMessage.authorUserId: "Listed Author",
        },
      );

      return MessagesBloc(
        messageRepo: FakeMessageRepository(fixture: fixture),
        profileRepo: countingProfileRepository,
        textSessionRepo: FakeTextSessionRepository(fixture: fixture),
        messageRuntimeService: FakeMessageRuntimeService(),
      );
    },
    act: (bloc) => bloc
      ..add(LoadMessagesRequested(channelId: fixture.listedChannel.id))
      ..add(
        UpdateMessageRequested(
          channelId: fixture.listedChannel.id,
          messageId: fixture.listedMessage.id,
          messageContent: "edited",
        ),
      ),
    verify: (bloc) {
      expect(
        countingProfileRepository.getOneCalls,
        1,
      );
    },
  );

  blocTest<MessagesBloc, MessagesState>(
    "updates message and emits loaded state",
    build: () => MessagesBloc(
      messageRepo: FakeMessageRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        displayNamesByUserId: <String, String?>{
          fixture.listedMessage.authorUserId: "Listed Author",
        },
      ),
      textSessionRepo: FakeTextSessionRepository(fixture: fixture),
      messageRuntimeService: FakeMessageRuntimeService(),
    ),
    act: (bloc) => bloc
      ..add(LoadMessagesRequested(
        channelId: fixture.listedChannel.id,
      ))
      ..add(UpdateMessageRequested(
        channelId: fixture.listedChannel.id,
        messageId: fixture.listedMessage.id,
        messageContent: "edited",
      )),
    expect: () => <Matcher>[
      isA<MessagesLoadingState>(),
      isA<MessagesLoadedState>(),
      isA<MessagesLoadingState>(),
      isA<MessagesLoadedState>()
          .having(
            (state) => state.messages.first.content,
            "updated content",
            "edited",
          )
          .having(
            (state) => state
                .authorDisplayNamesByUserId[fixture.listedMessage.authorUserId],
            "author display name",
            "Listed Author",
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
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
      ),
      textSessionRepo: FakeTextSessionRepository(fixture: fixture),
      messageRuntimeService: FakeMessageRuntimeService(),
    ),
    act: (bloc) => bloc
      ..add(LoadMessagesRequested(
        channelId: fixture.listedChannel.id,
      ))
      ..add(DeleteMessageRequested(
        channelId: fixture.listedChannel.id,
        messageId: fixture.listedMessage.id,
      )),
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
