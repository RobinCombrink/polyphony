import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetMessagesQuery {
  const GetMessagesQuery({
    required this.channelId,
  });

  final String channelId;
}

class CreateMessageCommand {
  const CreateMessageCommand({
    required this.channelId,
    required this.content,
    this.mentionedUserId,
  });

  final String channelId;
  final String content;
  final String? mentionedUserId;
}

class UpdateMessageCommand {
  const UpdateMessageCommand({
    required this.channelId,
    required this.messageId,
    required this.content,
  });

  final String channelId;
  final String messageId;
  final String content;
}

class DeleteMessageCommand {
  const DeleteMessageCommand({
    required this.channelId,
    required this.messageId,
  });

  final String channelId;
  final String messageId;
}

abstract interface class MessageRepo
    with
        RepositoryGetMany<Message, GetMessagesQuery>,
        RepositoryCreateOne<Message, CreateMessageCommand>,
        RepositoryUpdateOne<Message, UpdateMessageCommand>,
        RepositoryDeleteOne<DeleteMessageCommand> {}
