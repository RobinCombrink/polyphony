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
    final loadedState = _loadedStateOrNull(state);

    if (trimmedChannelId.isEmpty) {
      if (loadedState == null) {
        emit(MessagesExceptionState(
          error: Exception("Messages must be loaded before validation."),
        ));
        return;
      }

      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: loadedState.messages,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final listMessagesResult = await _messageRepo.getMany(
      query: GetMessagesQuery(
        channelId: trimmedChannelId,
      ),
    );

    switch (listMessagesResult) {
      case Ok<Iterable<Message>>(:final value):
        emit(MessagesLoadedState(
          messages: value.toList(),
          channelId: trimmedChannelId,
        ));
      case Error<Iterable<Message>>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onCreateMessageRequested(
    CreateMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final trimmedMessageContent = event.messageContent.trim();
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(MessagesExceptionState(
        error: Exception("Messages must be loaded before creating a message."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: loadedState.messages,
        channelId: loadedState.channelId,
      ));
      return;
    }

    if (trimmedMessageContent.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.messageContentRequired,
        messages: loadedState.messages,
        channelId: trimmedChannelId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final createMessageResult = await _messageRepo.createOne(
      command: CreateMessageCommand(
        channelId: trimmedChannelId,
        content: trimmedMessageContent,
      ),
    );

    switch (createMessageResult) {
      case Ok<Message>():
        final listMessagesResult = await _messageRepo.getMany(
          query: GetMessagesQuery(
            channelId: trimmedChannelId,
          ),
        );
        switch (listMessagesResult) {
          case Ok<Iterable<Message>>(:final value):
            emit(MessagesLoadedState(
              messages: value.toList(),
              channelId: trimmedChannelId,
            ));
          case Error<Iterable<Message>>(:final error):
            emit(MessagesExceptionState(error: error));
        }
      case Error<Message>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onUpdateMessageRequested(
    UpdateMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final trimmedMessageContent = event.messageContent.trim();
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(MessagesExceptionState(
        error: Exception("Messages must be loaded before updating a message."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: loadedState.messages,
        channelId: loadedState.channelId,
      ));
      return;
    }

    if (trimmedMessageContent.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.updatedContentRequired,
        messages: loadedState.messages,
        channelId: trimmedChannelId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final updateMessageResult = await _messageRepo.updateOne(
      command: UpdateMessageCommand(
        channelId: trimmedChannelId,
        messageId: event.messageId,
        content: trimmedMessageContent,
      ),
    );

    switch (updateMessageResult) {
      case Ok<Message>():
        final listMessagesResult = await _messageRepo.getMany(
          query: GetMessagesQuery(
            channelId: trimmedChannelId,
          ),
        );
        switch (listMessagesResult) {
          case Ok<Iterable<Message>>(:final value):
            emit(MessagesLoadedState(
              messages: value.toList(),
              channelId: trimmedChannelId,
            ));
          case Error<Iterable<Message>>(:final error):
            emit(MessagesExceptionState(error: error));
        }
      case Error<Message>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onDeleteMessageRequested(
    DeleteMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(MessagesExceptionState(
        error: Exception("Messages must be loaded before deleting a message."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: loadedState.messages,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final deleteMessageResult = await _messageRepo.deleteOne(
      command: DeleteMessageCommand(
        channelId: trimmedChannelId,
        messageId: event.messageId,
      ),
    );

    switch (deleteMessageResult) {
      case Ok<void>():
        final listMessagesResult = await _messageRepo.getMany(
          query: GetMessagesQuery(
            channelId: trimmedChannelId,
          ),
        );
        switch (listMessagesResult) {
          case Ok<Iterable<Message>>(:final value):
            emit(MessagesLoadedState(
              messages: value.toList(),
              channelId: trimmedChannelId,
            ));
          case Error<Iterable<Message>>(:final error):
            emit(MessagesExceptionState(error: error));
        }
      case Error<void>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  MessagesLoadedDataState? _loadedStateOrNull(MessagesState state) {
    return switch (state) {
      MessagesLoadedDataState() => state,
      _ => null,
    };
  }
}
