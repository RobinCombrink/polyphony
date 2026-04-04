part of "pinned_messages_bloc.dart";

sealed class PinnedMessagesState {
  const PinnedMessagesState();
}

final class PinnedMessagesInitialState extends PinnedMessagesState {
  const PinnedMessagesInitialState();
}

final class PinnedMessagesLoadingState extends PinnedMessagesState {
  const PinnedMessagesLoadingState();
}

final class PinnedMessagesLoadedState extends PinnedMessagesState {
  const PinnedMessagesLoadedState({
    required this.pinnedMessages,
    required this.serverId,
  });

  final List<PinnedMessage> pinnedMessages;
  final ServerId serverId;
}

final class PinnedMessagesExceptionState extends PinnedMessagesState {
  const PinnedMessagesExceptionState({required this.error});

  final Exception error;
}
