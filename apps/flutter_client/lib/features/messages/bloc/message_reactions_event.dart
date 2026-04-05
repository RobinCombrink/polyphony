part of "message_reactions_bloc.dart";

sealed class MessageReactionsEvent {
  const MessageReactionsEvent();
}

final class MessageReactionsLoadRequested extends MessageReactionsEvent {
  const MessageReactionsLoadRequested();
}

final class MessageReactionsToggleRequested extends MessageReactionsEvent {
  const MessageReactionsToggleRequested({
    required this.emoteId,
  });

  final String emoteId;
}
