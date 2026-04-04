part of "pinned_messages_bloc.dart";

sealed class PinnedMessagesEvent {
  const PinnedMessagesEvent();
}

final class LoadPinnedMessagesRequested extends PinnedMessagesEvent {
  const LoadPinnedMessagesRequested({required this.serverId});

  final ServerId serverId;
}

final class PinMessageRequested extends PinnedMessagesEvent {
  const PinMessageRequested({
    required this.serverId,
    required this.messageId,
  });

  final ServerId serverId;
  final MessageId messageId;
}

final class UnpinMessageRequested extends PinnedMessagesEvent {
  const UnpinMessageRequested({
    required this.serverId,
    required this.messageId,
  });

  final ServerId serverId;
  final MessageId messageId;
}
