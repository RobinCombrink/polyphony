import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
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
    required String currentUserId,
  })  : _directMessageRepo = directMessageRepo,
        _blockRepo = blockRepo,
        _currentUserId = currentUserId,
        super(const DirectMessagesInitialState()) {
    on<DirectMessagesEvent>(_onEvent, transformer: sequential());
  }

  final DirectMessageRepo _directMessageRepo;
  final BlockRepo _blockRepo;
  final String _currentUserId;

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

  String _peerUserIdForThread(DirectMessageThread thread) {
    return thread.participantAUserId == _currentUserId
        ? thread.participantBUserId
        : thread.participantAUserId;
  }

  Future<Set<String>> _loadBlockedUserIds() async {
    final blockedResult =
        await _blockRepo.getMany(query: const GetBlockedUsersQuery());

    return switch (blockedResult) {
      Ok<Iterable<BlockedUser>>(:final value) => value
          .map((user) => user.userId.trim())
          .where((id) => id.isNotEmpty)
          .toSet(),
      Error<Iterable<BlockedUser>>() => <String>{},
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
        emit(DirectMessagesLoadedState(
          threads: value.toList(growable: false),
          selectedThreadId: null,
          selectedThreadMessages: const <DirectMessage>[],
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
      final DirectMessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(DirectMessagesExceptionState(
        error: Exception(
            "Direct messages must be loaded before opening a thread."),
      ));
      return;
    }

    final trimmedUserId = event.userId.trim();
    if (trimmedUserId.isEmpty) {
      emit(DirectMessagesValidationFailedState(
        issue: DirectMessagesValidationIssue.userSelectionRequired,
        threads: loadedState.threads,
        selectedThreadId: loadedState.selectedThreadId,
        selectedThreadMessages: loadedState.selectedThreadMessages,
        blockedUserIds: loadedState.blockedUserIds,
      ));
      return;
    }

    final openResult = await _directMessageRepo.createOne(
      command: OpenOrGetDirectMessageThreadCommand(userId: trimmedUserId),
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
      final DirectMessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final threads = event.threadsOverride ?? loadedState.threads;
    final trimmedThreadId = event.threadId.trim();
    final selectedThread =
        threads.where((thread) => thread.id == trimmedThreadId).firstOrNull;

    if (selectedThread == null) {
      emit(DirectMessagesValidationFailedState(
        issue: DirectMessagesValidationIssue.threadSelectionRequired,
        threads: threads,
        selectedThreadId: loadedState.selectedThreadId,
        selectedThreadMessages: loadedState.selectedThreadMessages,
        blockedUserIds: loadedState.blockedUserIds,
      ));
      return;
    }

    final messagesResult = await _directMessageRepo.getOne(
      query: GetDirectMessagesQuery(threadId: trimmedThreadId),
    );

    switch (messagesResult) {
      case Ok<Iterable<DirectMessage>>(:final value):
        emit(DirectMessagesLoadedState(
          threads: threads,
          selectedThreadId: trimmedThreadId,
          selectedThreadMessages: value.toList(growable: false),
          blockedUserIds: loadedState.blockedUserIds,
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
      final DirectMessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(DirectMessagesExceptionState(
        error: Exception("Direct messages must be loaded before sending."),
      ));
      return;
    }

    final selectedThread = loadedState.selectedThread;
    if (selectedThread == null) {
      emit(DirectMessagesValidationFailedState(
        issue: DirectMessagesValidationIssue.threadSelectionRequired,
        threads: loadedState.threads,
        selectedThreadId: loadedState.selectedThreadId,
        selectedThreadMessages: loadedState.selectedThreadMessages,
        blockedUserIds: loadedState.blockedUserIds,
      ));
      return;
    }

    final peerUserId = _peerUserIdForThread(selectedThread);
    if (loadedState.blockedUserIds.contains(peerUserId)) {
      emit(DirectMessagesValidationFailedState(
        issue: DirectMessagesValidationIssue.blockedRelationship,
        threads: loadedState.threads,
        selectedThreadId: loadedState.selectedThreadId,
        selectedThreadMessages: loadedState.selectedThreadMessages,
        blockedUserIds: loadedState.blockedUserIds,
      ));
      return;
    }

    final trimmedContent = event.content.trim();
    if (trimmedContent.isEmpty) {
      emit(DirectMessagesValidationFailedState(
        issue: DirectMessagesValidationIssue.messageContentRequired,
        threads: loadedState.threads,
        selectedThreadId: loadedState.selectedThreadId,
        selectedThreadMessages: loadedState.selectedThreadMessages,
        blockedUserIds: loadedState.blockedUserIds,
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
        emit(DirectMessagesLoadedState(
          threads: loadedState.threads,
          selectedThreadId: loadedState.selectedThreadId,
          selectedThreadMessages: <DirectMessage>[
            ...loadedState.selectedThreadMessages,
            value,
          ],
          blockedUserIds: loadedState.blockedUserIds,
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
      final DirectMessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final selectedThread = loadedState.selectedThread;
    if (selectedThread == null) {
      return;
    }

    final peerUserId = _peerUserIdForThread(selectedThread);
    final unblockResult = await _blockRepo.deleteOne(
      command: UnblockUserCommand(userId: peerUserId),
    );

    switch (unblockResult) {
      case Ok<void>():
        emit(DirectMessagesLoadedState(
          threads: loadedState.threads,
          selectedThreadId: loadedState.selectedThreadId,
          selectedThreadMessages: loadedState.selectedThreadMessages,
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
