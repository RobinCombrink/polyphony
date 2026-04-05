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
    required this.blockedUserIds,
  });

  final List<DirectMessageThread> threads;
  final Set<UserId> blockedUserIds;
}

sealed class DirectMessagesLoadedState extends DirectMessagesLoadedDataState {
  const DirectMessagesLoadedState({
    required super.threads,
    required super.blockedUserIds,
  });

  DirectMessagesThreadSelected selectThread({
    required DirectMessageThread thread,
    required List<DirectMessage> messages,
    List<DirectMessageThread>? threadsOverride,
  }) {
    return DirectMessagesThreadSelected(
      threads: threadsOverride ?? threads,
      blockedUserIds: blockedUserIds,
      selectedThread: thread,
      selectedThreadMessages: messages,
    );
  }

  DirectMessagesValidationFailedState withValidationIssue({
    required DirectMessagesValidationIssue issue,
  }) {
    return switch (this) {
      DirectMessagesNoThreadSelected() =>
        DirectMessagesNoThreadSelectedValidationFailedState(
          issue: issue,
          threads: threads,
          blockedUserIds: blockedUserIds,
        ),
      DirectMessagesThreadSelected(
        :final selectedThread,
        :final selectedThreadMessages,
      ) =>
        DirectMessagesThreadSelectedValidationFailedState(
          issue: issue,
          threads: threads,
          blockedUserIds: blockedUserIds,
          selectedThread: selectedThread,
          selectedThreadMessages: selectedThreadMessages,
        ),
      final DirectMessagesValidationFailedState validationState =>
        validationState,
    };
  }

  DirectMessagesLoadedState withUpdatedBlockedUserIds({
    required Set<UserId> blockedUserIds,
  }) {
    return switch (this) {
      DirectMessagesNoThreadSelected() => DirectMessagesNoThreadSelected(
          threads: threads,
          blockedUserIds: blockedUserIds,
        ),
      DirectMessagesThreadSelected(
        :final selectedThread,
        :final selectedThreadMessages,
      ) =>
        DirectMessagesThreadSelected(
          threads: threads,
          blockedUserIds: blockedUserIds,
          selectedThread: selectedThread,
          selectedThreadMessages: selectedThreadMessages,
        ),
      DirectMessagesNoThreadSelectedValidationFailedState() =>
        DirectMessagesNoThreadSelected(
          threads: threads,
          blockedUserIds: blockedUserIds,
        ),
      DirectMessagesThreadSelectedValidationFailedState(
        :final selectedThread,
        :final selectedThreadMessages,
      ) =>
        DirectMessagesThreadSelected(
          threads: threads,
          blockedUserIds: blockedUserIds,
          selectedThread: selectedThread,
          selectedThreadMessages: selectedThreadMessages,
        ),
    };
  }
}

final class DirectMessagesNoThreadSelected extends DirectMessagesLoadedState {
  const DirectMessagesNoThreadSelected({
    required super.threads,
    required super.blockedUserIds,
  });
}

final class DirectMessagesThreadSelected extends DirectMessagesLoadedState {
  const DirectMessagesThreadSelected({
    required super.threads,
    required super.blockedUserIds,
    required this.selectedThread,
    required this.selectedThreadMessages,
  });

  final DirectMessageThread selectedThread;
  final List<DirectMessage> selectedThreadMessages;

  bool get selectedThreadIsBlocked {
    return blockedUserIds.contains(selectedThread.participantAUserId) ||
        blockedUserIds.contains(selectedThread.participantBUserId);
  }

  DirectMessagesThreadSelected withAppendedMessage(DirectMessage message) {
    return DirectMessagesThreadSelected(
      threads: threads,
      blockedUserIds: blockedUserIds,
      selectedThread: selectedThread,
      selectedThreadMessages: <DirectMessage>[
        ...selectedThreadMessages,
        message,
      ],
    );
  }
}

sealed class DirectMessagesValidationFailedState
    extends DirectMessagesLoadedState {
  const DirectMessagesValidationFailedState({
    required this.issue,
    required super.threads,
    required super.blockedUserIds,
  });

  final DirectMessagesValidationIssue issue;
}

final class DirectMessagesNoThreadSelectedValidationFailedState
    extends DirectMessagesValidationFailedState {
  const DirectMessagesNoThreadSelectedValidationFailedState({
    required super.issue,
    required super.threads,
    required super.blockedUserIds,
  });
}

final class DirectMessagesThreadSelectedValidationFailedState
    extends DirectMessagesValidationFailedState {
  const DirectMessagesThreadSelectedValidationFailedState({
    required super.issue,
    required super.threads,
    required super.blockedUserIds,
    required this.selectedThread,
    required this.selectedThreadMessages,
  });

  final DirectMessageThread selectedThread;
  final List<DirectMessage> selectedThreadMessages;

  bool get selectedThreadIsBlocked {
    return blockedUserIds.contains(selectedThread.participantAUserId) ||
        blockedUserIds.contains(selectedThread.participantBUserId);
  }
}

final class DirectMessagesExceptionState extends DirectMessagesState {
  const DirectMessagesExceptionState({required this.error});

  final Exception error;
}
