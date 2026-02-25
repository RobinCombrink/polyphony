part of "messages_bloc.dart";

enum MessagesValidationIssue {
  channelSelectionRequired,
  messageContentRequired,
  updatedContentRequired,
}

sealed class MessagesState {
  const MessagesState({required this.messages, required this.channelId});

  final List<Message> messages;
  final String? channelId;

  bool get isLoading => this is MessagesLoadingState;
}

final class MessagesInitialState extends MessagesState {
  const MessagesInitialState()
      : super(messages: const <Message>[], channelId: null);
}

final class MessagesLoadingState extends MessagesState {
  const MessagesLoadingState({
    required super.messages,
    required super.channelId,
  });
}

final class MessagesLoadedState extends MessagesState {
  const MessagesLoadedState({
    required super.messages,
    required super.channelId,
  });
}

final class MessagesValidationFailedState extends MessagesState {
  const MessagesValidationFailedState({
    required this.issue,
    required super.messages,
    required super.channelId,
  });

  final MessagesValidationIssue issue;
}

final class MessagesExceptionState extends MessagesState {
  const MessagesExceptionState({
    required this.error,
    required super.messages,
    required super.channelId,
  });

  final Exception error;
}
