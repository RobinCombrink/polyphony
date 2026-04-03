import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/direct_message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/direct_message_service.dart";

class DirectMessageRepository implements DirectMessageRepo {
  const DirectMessageRepository({
    required DirectMessageService directMessageService,
  }) : _directMessageService = directMessageService;

  final DirectMessageService _directMessageService;

  @override
  Future<Result<DirectMessageThread>> createOne({
    required OpenOrGetDirectMessageThreadCommand command,
  }) async {
    final serviceResult = await _directMessageService.openOrGetThread(
      userId: command.userId.value,
    );

    return switch (serviceResult) {
      Ok<ApiDirectMessageThread>(:final value) =>
        Ok<DirectMessageThread>(value.toDomainModel()),
      Error<ApiDirectMessageThread>(:final error) =>
        Error<DirectMessageThread>(error),
    };
  }

  @override
  Future<Result<Iterable<DirectMessage>>> getOne({
    required GetDirectMessagesQuery query,
  }) async {
    final serviceResult = await _directMessageService.listMessages(
      threadId: query.threadId.value,
    );

    return switch (serviceResult) {
      Ok<List<ApiDirectMessage>>(:final value) => Ok<Iterable<DirectMessage>>(
          value.map((message) => message.toDomainModel()).toList()),
      Error<List<ApiDirectMessage>>(:final error) =>
        Error<Iterable<DirectMessage>>(error),
    };
  }

  @override
  Future<Result<Iterable<DirectMessageThread>>> getMany({
    required GetDirectMessageThreadsQuery query,
  }) async {
    final serviceResult = await _directMessageService.listThreads();

    return switch (serviceResult) {
      Ok<List<ApiDirectMessageThread>>(:final value) =>
        Ok<Iterable<DirectMessageThread>>(
          value.map((thread) => thread.toDomainModel()).toList(),
        ),
      Error<List<ApiDirectMessageThread>>(:final error) =>
        Error<Iterable<DirectMessageThread>>(error),
    };
  }

  @override
  Future<Result<DirectMessage>> updateOne({
    required SendDirectMessageCommand command,
  }) async {
    final serviceResult = await _directMessageService.sendMessage(
      threadId: command.threadId.value,
      content: command.content,
    );

    return switch (serviceResult) {
      Ok<ApiDirectMessage>(:final value) =>
        Ok<DirectMessage>(value.toDomainModel()),
      Error<ApiDirectMessage>(:final error) => Error<DirectMessage>(error),
    };
  }

  @override
  Future<Result<Iterable<DirectMessage>>> updateMany({
    required SearchDirectMessagesForUserCommand command,
  }) async {
    final serviceResult = await _directMessageService.searchMessagesForUser(
      userId: command.userId.value,
      query: command.query,
    );

    return switch (serviceResult) {
      Ok<List<ApiDirectMessage>>(:final value) => Ok<Iterable<DirectMessage>>(
          value.map((message) => message.toDomainModel()).toList()),
      Error<List<ApiDirectMessage>>(:final error) =>
        Error<Iterable<DirectMessage>>(error),
    };
  }
}
