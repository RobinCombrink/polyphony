part of "messages_bloc.dart";

sealed class MessagesEvent {
  const MessagesEvent();
}

final class ResetMessagesRequested extends MessagesEvent {
  const ResetMessagesRequested();
}

final class LoadMessagesRequested extends MessagesEvent {
  const LoadMessagesRequested({
    required this.channelId,
  });

  final ChannelId channelId;
}

final class CreateMessageRequested extends MessagesEvent {
  const CreateMessageRequested({
    required this.channelId,
    required this.messageContent,
    this.mentionedUserId,
  });

  final ChannelId channelId;
  final String messageContent;
  final UserId? mentionedUserId;
}

final class UpdateMessageRequested extends MessagesEvent {
  const UpdateMessageRequested({
    required this.channelId,
    required this.messageId,
    required this.messageContent,
  });

  final ChannelId channelId;
  final MessageId messageId;
  final String messageContent;
}

final class DeleteMessageRequested extends MessagesEvent {
  const DeleteMessageRequested({
    required this.channelId,
    required this.messageId,
  });

  final ChannelId channelId;
  final MessageId messageId;
}

final class RealtimeMessageReceived extends MessagesEvent {
  const RealtimeMessageReceived({
    required this.channelId,
    required this.authorUserId,
    required this.content,
  });

  final ChannelId channelId;
  final UserId authorUserId;
  final String content;
}
