part of "messages_bloc.dart";

enum MessagesValidationIssue {
  channelSelectionRequired,
  messageContentRequired,
  updatedContentRequired,
}

sealed class MessagesState {
  const MessagesState();
}

final class MessagesInitialState extends MessagesState {
  const MessagesInitialState();
}

final class MessagesLoadingState extends MessagesState {
  const MessagesLoadingState();
}

sealed class MessagesLoadedDataState extends MessagesState {
  const MessagesLoadedDataState({
    required this.messages,
    required this.channelId,
  });

  final List<Message> messages;
  final String channelId;
}

final class MessagesLoadedState extends MessagesLoadedDataState {
  const MessagesLoadedState({
    required super.messages,
    required super.channelId,
  });
}

final class MessagesValidationFailedState extends MessagesLoadedDataState {
  const MessagesValidationFailedState({
    required this.issue,
    required super.messages,
    required super.channelId,
  });

  final MessagesValidationIssue issue;
}

final class MessagesExceptionState extends MessagesState {
  const MessagesExceptionState({required this.error});

  final Exception error;
}
