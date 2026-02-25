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
  Future<Result<List<Message>>> listMessages({
    required String baseUrl,
    required String channelId,
  }) async {
    final serviceResult = await _messageService.listMessages(
      baseUrl: baseUrl,
      channelId: channelId,
    );

    return switch (serviceResult) {
      Ok<List<ApiMessage>>(:final value) => Ok<List<Message>>(
          value.map((message) => message.toDomainModel()).toList(),
        ),
      Error<List<ApiMessage>>(:final error) => Error<List<Message>>(error),
    };
  }

  @override
  Future<Result<Message>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
  }) async {
    final serviceResult = await _messageService.createMessage(
      baseUrl: baseUrl,
      channelId: channelId,
      content: content,
    );

    return switch (serviceResult) {
      Ok<ApiMessage>(:final value) => Ok<Message>(value.toDomainModel()),
      Error<ApiMessage>(:final error) => Error<Message>(error),
    };
  }

  @override
  Future<Result<Message>> updateMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
    required String content,
  }) async {
    final serviceResult = await _messageService.updateMessage(
      baseUrl: baseUrl,
      channelId: channelId,
      messageId: messageId,
      content: content,
    );

    return switch (serviceResult) {
      Ok<ApiMessage>(:final value) => Ok<Message>(value.toDomainModel()),
      Error<ApiMessage>(:final error) => Error<Message>(error),
    };
  }

  @override
  Future<Result<void>> deleteMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
  }) {
    return _messageService.deleteMessage(
      baseUrl: baseUrl,
      channelId: channelId,
      messageId: messageId,
    );
  }
}
