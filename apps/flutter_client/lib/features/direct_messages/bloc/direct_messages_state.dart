part of "direct_messages_bloc.dart";

enum DirectMessagesValidationIssue {
  threadSelectionRequired,
  userSelectionRequired,
  messageContentRequired,
  blockedRelationship,
}

sealed class DirectMessagesState {
  const DirectMessagesState();
}

final class DirectMessagesInitialState extends DirectMessagesState {
  const DirectMessagesInitialState();
}

final class DirectMessagesLoadingState extends DirectMessagesState {
  const DirectMessagesLoadingState();
}

sealed class DirectMessagesLoadedDataState extends DirectMessagesState {
  const DirectMessagesLoadedDataState({
    required this.threads,
    required this.selectedThreadId,
    required this.selectedThreadMessages,
    required this.blockedUserIds,
  });

  final List<DirectMessageThread> threads;
  final String? selectedThreadId;
  final List<DirectMessage> selectedThreadMessages;
  final Set<String> blockedUserIds;

  DirectMessageThread? get selectedThread {
    final threadId = selectedThreadId;
    if (threadId == null) {
      return null;
    }

    for (final thread in threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }

    return null;
  }

  bool get selectedThreadIsBlocked {
    final thread = selectedThread;
    if (thread == null) {
      return false;
    }

    return blockedUserIds.contains(thread.participantAUserId) ||
        blockedUserIds.contains(thread.participantBUserId);
  }
}

final class DirectMessagesLoadedState extends DirectMessagesLoadedDataState {
  const DirectMessagesLoadedState({
    required super.threads,
    required super.selectedThreadId,
    required super.selectedThreadMessages,
    required super.blockedUserIds,
  });
}

final class DirectMessagesValidationFailedState
    extends DirectMessagesLoadedDataState {
  const DirectMessagesValidationFailedState({
    required this.issue,
    required super.threads,
    required super.selectedThreadId,
    required super.selectedThreadMessages,
    required super.blockedUserIds,
  });

  final DirectMessagesValidationIssue issue;
}

final class DirectMessagesExceptionState extends DirectMessagesState {
  const DirectMessagesExceptionState({required this.error});

  final Exception error;
}
