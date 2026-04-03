import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetDirectMessageThreadsQuery {
  const GetDirectMessageThreadsQuery();
}

class OpenOrGetDirectMessageThreadCommand {
  const OpenOrGetDirectMessageThreadCommand({required this.userId});

  final UserId userId;
}

class GetDirectMessagesQuery {
  const GetDirectMessagesQuery({required this.threadId});

  final DirectMessageThreadId threadId;
}

class SendDirectMessageCommand {
  const SendDirectMessageCommand({
    required this.threadId,
    required this.content,
  });

  final DirectMessageThreadId threadId;
  final String content;
}

class SearchDirectMessagesForUserCommand {
  const SearchDirectMessagesForUserCommand({
    required this.userId,
    required this.query,
  });

  final UserId userId;
  final String query;
}

abstract interface class DirectMessageRepo
    with
        RepositoryGetMany<DirectMessageThread, GetDirectMessageThreadsQuery>,
        RepositoryCreateOne<DirectMessageThread,
            OpenOrGetDirectMessageThreadCommand>,
        RepositoryGetOne<Iterable<DirectMessage>, GetDirectMessagesQuery>,
        RepositoryUpdateOne<DirectMessage, SendDirectMessageCommand>,
        RepositoryUpdateMany<DirectMessage,
            SearchDirectMessagesForUserCommand> {}
