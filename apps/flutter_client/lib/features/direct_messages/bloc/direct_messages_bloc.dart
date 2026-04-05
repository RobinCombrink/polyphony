import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/block_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/direct_message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "direct_messages_event.dart";
part "direct_messages_state.dart";

class DirectMessagesBloc
    extends Bloc<DirectMessagesEvent, DirectMessagesState> {
  DirectMessagesBloc({
    required DirectMessageRepo directMessageRepo,
    required BlockRepo blockRepo,
    required UserId currentUserId,
  })  : _directMessageRepo = directMessageRepo,
        _blockRepo = blockRepo,
        _currentUserId = currentUserId,
        super(const DirectMessagesInitialState()) {
    on<DirectMessagesEvent>(_onEvent, transformer: sequential());
  }

  final DirectMessageRepo _directMessageRepo;
  final BlockRepo _blockRepo;
  final UserId _currentUserId;

  Future<void> _onEvent(
    DirectMessagesEvent event,
    Emitter<DirectMessagesState> emit,
  ) async {
    switch (event) {
      case LoadDirectMessageThreadsRequested():
        await _onLoadDirectMessageThreadsRequested(event, emit);
      case OpenDirectMessageThreadRequested():
        await _onOpenDirectMessageThreadRequested(event, emit);
      case SelectDirectMessageThreadRequested():
        await _onSelectDirectMessageThreadRequested(event, emit);
      case SendDirectMessageRequested():
        await _onSendDirectMessageRequested(event, emit);
      case UnblockSelectedDirectMessageUserRequested():
        await _onUnblockSelectedDirectMessageUserRequested(event, emit);
    }
  }

  UserId _peerUserIdForThread(DirectMessageThread thread) {
    return thread.participantAUserId == _currentUserId
        ? thread.participantBUserId
        : thread.participantAUserId;
  }

  Future<Set<UserId>> _loadBlockedUserIds() async {
    final blockedResult =
        await _blockRepo.getMany(query: const GetBlockedUsersQuery());

    return switch (blockedResult) {
      Ok<Iterable<BlockedUser>>(:final value) => value
          .map((user) => user.userId)
          .where((id) => id.value.trim().isNotEmpty)
          .toSet(),
      Error<Iterable<BlockedUser>>() => <UserId>{},
    };
  }

  Future<void> _onLoadDirectMessageThreadsRequested(
    LoadDirectMessageThreadsRequested event,
    Emitter<DirectMessagesState> emit,
  ) async {
    emit(const DirectMessagesLoadingState());

    final threadsResult = await _directMessageRepo.getMany(
        query: const GetDirectMessageThreadsQuery());
    final blockedUserIds = await _loadBlockedUserIds();

    switch (threadsResult) {
      case Ok<Iterable<DirectMessageThread>>(:final value):
        emit(DirectMessagesNoThreadSelected(
          threads: value.toList(growable: false),
          blockedUserIds: blockedUserIds,
        ));
      case Error<Iterable<DirectMessageThread>>(:final error):
        emit(DirectMessagesExceptionState(error: error));
    }
  }

  Future<void> _onOpenDirectMessageThreadRequested(
    OpenDirectMessageThreadRequested event,
    Emitter<DirectMessagesState> emit,
  ) async {
    final loadedState = switch (state) {
      final DirectMessagesLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(DirectMessagesExceptionState(
        error: Exception(
            "Direct messages must be loaded before opening a thread."),
      ));
      return;
    }

    final trimmedUserId = event.userId.value.trim();
    if (trimmedUserId.isEmpty) {
      emit(loadedState.withValidationIssue(
        issue: DirectMessagesValidationIssue.userSelectionRequired,
      ));
      return;
    }

    final openResult = await _directMessageRepo.createOne(
      command: OpenOrGetDirectMessageThreadCommand(userId: event.userId),
    );

    switch (openResult) {
      case Ok<DirectMessageThread>(:final value):
        final mergedThreads = <DirectMessageThread>[
          ...loadedState.threads.where((thread) => thread.id != value.id),
          value,
        ];

        add(SelectDirectMessageThreadRequested(
            threadId: value.id, threadsOverride: mergedThreads));
      case Error<DirectMessageThread>(:final error):
        emit(DirectMessagesExceptionState(error: error));
    }
  }

  Future<void> _onSelectDirectMessageThreadRequested(
    SelectDirectMessageThreadRequested event,
    Emitter<DirectMessagesState> emit,
  ) async {
    final loadedState = switch (state) {
      final DirectMessagesLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final threads = event.threadsOverride ?? loadedState.threads;
    final selectedThread =
        threads.where((thread) => thread.id == event.threadId).firstOrNull;

    if (selectedThread == null) {
      emit(loadedState.withValidationIssue(
        issue: DirectMessagesValidationIssue.threadSelectionRequired,
      ));
      return;
    }

    final messagesResult = await _directMessageRepo.getOne(
      query: GetDirectMessagesQuery(threadId: event.threadId),
    );

    switch (messagesResult) {
      case Ok<Iterable<DirectMessage>>(:final value):
        emit(loadedState.selectThread(
          thread: selectedThread,
          messages: value.toList(growable: false),
          threadsOverride: event.threadsOverride,
        ));
      case Error<Iterable<DirectMessage>>(:final error):
        emit(DirectMessagesExceptionState(error: error));
    }
  }

  Future<void> _onSendDirectMessageRequested(
    SendDirectMessageRequested event,
    Emitter<DirectMessagesState> emit,
  ) async {
    final loadedState = switch (state) {
      final DirectMessagesLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(DirectMessagesExceptionState(
        error: Exception("Direct messages must be loaded before sending."),
      ));
      return;
    }

    final (selectedThread, currentMessages) = switch (loadedState) {
      DirectMessagesThreadSelected(
        :final selectedThread,
        :final selectedThreadMessages,
      ) ||
      DirectMessagesThreadSelectedValidationFailedState(
        :final selectedThread,
        :final selectedThreadMessages,
      ) =>
        (selectedThread, selectedThreadMessages),
      _ => (null, null),
    };

    if (selectedThread == null || currentMessages == null) {
      emit(loadedState.withValidationIssue(
        issue: DirectMessagesValidationIssue.threadSelectionRequired,
      ));
      return;
    }

    final peerUserId = _peerUserIdForThread(selectedThread);
    if (loadedState.blockedUserIds.contains(peerUserId)) {
      emit(loadedState.withValidationIssue(
        issue: DirectMessagesValidationIssue.blockedRelationship,
      ));
      return;
    }

    final trimmedContent = event.content.trim();
    if (trimmedContent.isEmpty) {
      emit(loadedState.withValidationIssue(
        issue: DirectMessagesValidationIssue.messageContentRequired,
      ));
      return;
    }

    final sendResult = await _directMessageRepo.updateOne(
      command: SendDirectMessageCommand(
        threadId: selectedThread.id,
        content: trimmedContent,
      ),
    );

    switch (sendResult) {
      case Ok<DirectMessage>(:final value):
        emit(loadedState.selectThread(
          thread: selectedThread,
          messages: <DirectMessage>[
            ...currentMessages,
            value,
          ],
        ));
      case Error<DirectMessage>(:final error):
        emit(DirectMessagesExceptionState(error: error));
    }
  }

  Future<void> _onUnblockSelectedDirectMessageUserRequested(
    UnblockSelectedDirectMessageUserRequested event,
    Emitter<DirectMessagesState> emit,
  ) async {
    final loadedState = switch (state) {
      final DirectMessagesLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final selectedThread = switch (loadedState) {
      DirectMessagesThreadSelected(:final selectedThread) ||
      DirectMessagesThreadSelectedValidationFailedState(
        :final selectedThread,
      ) =>
        selectedThread,
      _ => null,
    };

    if (selectedThread == null) {
      return;
    }

    final peerUserId = _peerUserIdForThread(selectedThread);
    final unblockResult = await _blockRepo.deleteOne(
      command: UnblockUserCommand(userId: peerUserId),
    );

    switch (unblockResult) {
      case Ok<void>():
        emit(loadedState.withUpdatedBlockedUserIds(
          blockedUserIds: loadedState.blockedUserIds
              .where((userId) => userId != peerUserId)
              .toSet(),
        ));
      case Error<void>(:final error):
        emit(DirectMessagesExceptionState(error: error));
    }
  }
}

extension on Iterable<DirectMessageThread> {
  DirectMessageThread? get firstOrNull {
    for (final value in this) {
      return value;
    }

    return null;
  }
}
