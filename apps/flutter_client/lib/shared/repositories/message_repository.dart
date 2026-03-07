import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";

class MessageRepository implements MessageRepo {
  const MessageRepository({required MessageService messageService})
      : _messageService = messageService;

  final MessageService _messageService;

  @override
  Future<Result<Iterable<Message>>> getMany({
    required GetMessagesQuery query,
  }) async {
    final serviceResult = await _messageService.listMessages(
      channelId: query.channelId,
    );

    return switch (serviceResult) {
      Ok<List<ApiMessage>>(:final value) => Ok<Iterable<Message>>(
          value.map((message) => message.toDomainModel()).toList(),
        ),
      Error<List<ApiMessage>>(:final error) => Error<Iterable<Message>>(error),
    };
  }

  @override
  Future<Result<Message>> createOne({
    required CreateMessageCommand command,
  }) async {
    final serviceResult = await _messageService.createMessage(
      channelId: command.channelId,
      content: command.content,
      mentionedUserId: command.mentionedUserId,
    );

    return switch (serviceResult) {
      Ok<ApiMessage>(:final value) => Ok<Message>(value.toDomainModel()),
      Error<ApiMessage>(:final error) => Error<Message>(error),
    };
  }

  @override
  Future<Result<Message>> updateOne({
    required UpdateMessageCommand command,
  }) async {
    final serviceResult = await _messageService.updateMessage(
      channelId: command.channelId,
      messageId: command.messageId,
      content: command.content,
    );

    return switch (serviceResult) {
      Ok<ApiMessage>(:final value) => Ok<Message>(value.toDomainModel()),
      Error<ApiMessage>(:final error) => Error<Message>(error),
    };
  }

  @override
  Future<Result<void>> deleteOne({required DeleteMessageCommand command}) {
    return _messageService.deleteMessage(
      channelId: command.channelId,
      messageId: command.messageId,
    );
  }
}
