part of "message_search_bloc.dart";

sealed class MessageSearchState {
  const MessageSearchState();
}

final class MessageSearchInitialState extends MessageSearchState {
  const MessageSearchInitialState();
}

final class MessageSearchLoadingState extends MessageSearchState {
  const MessageSearchLoadingState();
}

final class MessageSearchLoadedState extends MessageSearchState {
  const MessageSearchLoadedState({
    required this.results,
  });

  final List<Message> results;
}

final class MessageSearchExceptionState extends MessageSearchState {
  const MessageSearchExceptionState({
    required this.error,
  });

  final Exception error;
}
