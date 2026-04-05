part of "message_reactions_bloc.dart";

sealed class MessageReactionsState {
  const MessageReactionsState();
}

final class MessageReactionsInitialState extends MessageReactionsState {
  const MessageReactionsInitialState();
}

final class MessageReactionsLoadingState extends MessageReactionsState {
  const MessageReactionsLoadingState();
}

final class MessageReactionsLoadedState extends MessageReactionsState {
  const MessageReactionsLoadedState({
    required this.reactions,
  });

  final List<ReactionSummary> reactions;
}

final class MessageReactionsExceptionState extends MessageReactionsState {
  const MessageReactionsExceptionState({
    required this.error,
  });

  final Exception error;
}
