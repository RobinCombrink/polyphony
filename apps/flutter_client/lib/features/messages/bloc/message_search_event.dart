part of "message_search_bloc.dart";

sealed class MessageSearchEvent {
  const MessageSearchEvent();
}

final class MessageSearchQueryChanged extends MessageSearchEvent {
  const MessageSearchQueryChanged({
    required this.channelId,
    required this.query,
  });

  final ChannelId channelId;
  final String query;
}

final class MessageSearchCleared extends MessageSearchEvent {
  const MessageSearchCleared();
}
