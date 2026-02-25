import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "messages_event.dart";
part "messages_state.dart";

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc({required MessageRepo messageRepo})
      : _messageRepo = messageRepo,
        super(const MessagesInitialState()) {
    on<ResetMessagesRequested>(_onResetMessagesRequested);
    on<LoadMessagesRequested>(_onLoadMessagesRequested);
    on<CreateMessageRequested>(_onCreateMessageRequested);
    on<UpdateMessageRequested>(_onUpdateMessageRequested);
    on<DeleteMessageRequested>(_onDeleteMessageRequested);
  }

  final MessageRepo _messageRepo;

  void _onResetMessagesRequested(
    ResetMessagesRequested event,
    Emitter<MessagesState> emit,
  ) {
    emit(const MessagesInitialState());
  }

  Future<void> _onLoadMessagesRequested(
    LoadMessagesRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: state.messages,
        channelId: state.channelId,
      ));
      return;
    }

    emit(MessagesLoadingState(
      messages: state.messages,
      channelId: trimmedChannelId,
    ));

    final listMessagesResult = await _messageRepo.listMessages(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
    );

    switch (listMessagesResult) {
      case Ok<List<Message>>(:final value):
        emit(MessagesLoadedState(messages: value, channelId: trimmedChannelId));
      case Error<List<Message>>(:final error):
        emit(MessagesExceptionState(
          error: error,
          messages: state.messages,
          channelId: state.channelId,
        ));
    }
  }

  Future<void> _onCreateMessageRequested(
    CreateMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final trimmedMessageContent = event.messageContent.trim();

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: state.messages,
        channelId: state.channelId,
      ));
      return;
    }

    if (trimmedMessageContent.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.messageContentRequired,
        messages: state.messages,
        channelId: trimmedChannelId,
      ));
      return;
    }

    emit(MessagesLoadingState(
      messages: state.messages,
      channelId: trimmedChannelId,
    ));

    final createMessageResult = await _messageRepo.createMessage(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
      content: trimmedMessageContent,
    );

    switch (createMessageResult) {
      case Ok<Message>():
        final listMessagesResult = await _messageRepo.listMessages(
          baseUrl: event.baseUrl.trim(),
          channelId: trimmedChannelId,
        );
        switch (listMessagesResult) {
          case Ok<List<Message>>(:final value):
            emit(MessagesLoadedState(
              messages: value,
              channelId: trimmedChannelId,
            ));
          case Error<List<Message>>(:final error):
            emit(MessagesExceptionState(
              error: error,
              messages: state.messages,
              channelId: state.channelId,
            ));
        }
      case Error<Message>(:final error):
        emit(MessagesExceptionState(
          error: error,
          messages: state.messages,
          channelId: state.channelId,
        ));
    }
  }

  Future<void> _onUpdateMessageRequested(
    UpdateMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final trimmedMessageContent = event.messageContent.trim();

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: state.messages,
        channelId: state.channelId,
      ));
      return;
    }

    if (trimmedMessageContent.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.updatedContentRequired,
        messages: state.messages,
        channelId: trimmedChannelId,
      ));
      return;
    }

    emit(MessagesLoadingState(
      messages: state.messages,
      channelId: trimmedChannelId,
    ));

    final updateMessageResult = await _messageRepo.updateMessage(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
      messageId: event.messageId,
      content: trimmedMessageContent,
    );

    switch (updateMessageResult) {
      case Ok<Message>():
        final listMessagesResult = await _messageRepo.listMessages(
          baseUrl: event.baseUrl.trim(),
          channelId: trimmedChannelId,
        );
        switch (listMessagesResult) {
          case Ok<List<Message>>(:final value):
            emit(MessagesLoadedState(
              messages: value,
              channelId: trimmedChannelId,
            ));
          case Error<List<Message>>(:final error):
            emit(MessagesExceptionState(
              error: error,
              messages: state.messages,
              channelId: state.channelId,
            ));
        }
      case Error<Message>(:final error):
        emit(MessagesExceptionState(
          error: error,
          messages: state.messages,
          channelId: state.channelId,
        ));
    }
  }

  Future<void> _onDeleteMessageRequested(
    DeleteMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: state.messages,
        channelId: state.channelId,
      ));
      return;
    }

    emit(MessagesLoadingState(
      messages: state.messages,
      channelId: trimmedChannelId,
    ));

    final deleteMessageResult = await _messageRepo.deleteMessage(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
      messageId: event.messageId,
    );

    switch (deleteMessageResult) {
      case Ok<void>():
        final listMessagesResult = await _messageRepo.listMessages(
          baseUrl: event.baseUrl.trim(),
          channelId: trimmedChannelId,
        );
        switch (listMessagesResult) {
          case Ok<List<Message>>(:final value):
            emit(MessagesLoadedState(
              messages: value,
              channelId: trimmedChannelId,
            ));
          case Error<List<Message>>(:final error):
            emit(MessagesExceptionState(
              error: error,
              messages: state.messages,
              channelId: state.channelId,
            ));
        }
      case Error<void>(:final error):
        emit(MessagesExceptionState(
          error: error,
          messages: state.messages,
          channelId: state.channelId,
        ));
    }
  }
}
