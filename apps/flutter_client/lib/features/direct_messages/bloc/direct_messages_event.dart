part of "direct_messages_bloc.dart";

sealed class DirectMessagesEvent {
  const DirectMessagesEvent();
}

final class LoadDirectMessageThreadsRequested extends DirectMessagesEvent {
  const LoadDirectMessageThreadsRequested();
}

final class OpenDirectMessageThreadRequested extends DirectMessagesEvent {
  const OpenDirectMessageThreadRequested({required this.userId});

  final String userId;
}

final class SelectDirectMessageThreadRequested extends DirectMessagesEvent {
  const SelectDirectMessageThreadRequested({
    required this.threadId,
    this.threadsOverride,
  });

  final String threadId;
  final List<DirectMessageThread>? threadsOverride;
}

final class SendDirectMessageRequested extends DirectMessagesEvent {
  const SendDirectMessageRequested({required this.content});

  final String content;
}

final class UnblockSelectedDirectMessageUserRequested
    extends DirectMessagesEvent {
  const UnblockSelectedDirectMessageUserRequested();
}
