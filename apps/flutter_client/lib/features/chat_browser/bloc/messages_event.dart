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

  final String channelId;
}

final class CreateMessageRequested extends MessagesEvent {
  const CreateMessageRequested({
    required this.channelId,
    required this.messageContent,
  });

  final String channelId;
  final String messageContent;
}

final class UpdateMessageRequested extends MessagesEvent {
  const UpdateMessageRequested({
    required this.channelId,
    required this.messageId,
    required this.messageContent,
  });

  final String channelId;
  final String messageId;
  final String messageContent;
}

final class DeleteMessageRequested extends MessagesEvent {
  const DeleteMessageRequested({
    required this.channelId,
    required this.messageId,
  });

  final String channelId;
  final String messageId;
}
