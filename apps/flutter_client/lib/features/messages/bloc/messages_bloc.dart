import "dart:async";

import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";

part "messages_event.dart";
part "messages_state.dart";

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc({
    required MessageRepo messageRepo,
    required ProfileRepo profileRepo,
    required TextSessionRepo textSessionRepo,
    required MessageRuntimeService messageRuntimeService,
  })  : _messageRepo = messageRepo,
        _profileRepo = profileRepo,
        _textSessionRepo = textSessionRepo,
        _messageRuntimeService = messageRuntimeService,
        super(const MessagesInitialState()) {
    on<MessagesEvent>(
      _onMessagesEvent,
      transformer: sequential(),
    );

    _runtimeTextSubscription =
        _messageRuntimeService.textMessages().listen((runtimeMessage) {
      add(RealtimeMessageReceived(
        channelId: runtimeMessage.channelId,
        authorUserId: runtimeMessage.authorUserId,
        content: runtimeMessage.content,
      ));
    });
  }

  final MessageRepo _messageRepo;
  final ProfileRepo _profileRepo;
  final TextSessionRepo _textSessionRepo;
  final MessageRuntimeService _messageRuntimeService;
  StreamSubscription<RuntimeTextMessage>? _runtimeTextSubscription;

  Future<void> _onMessagesEvent(
    MessagesEvent event,
    Emitter<MessagesState> emit,
  ) async {
    switch (event) {
      case ResetMessagesRequested():
        _onResetMessagesRequested(event, emit);
      case LoadMessagesRequested():
        await _onLoadMessagesRequested(event, emit);
      case CreateMessageRequested():
        await _onCreateMessageRequested(event, emit);
      case UpdateMessageRequested():
        await _onUpdateMessageRequested(event, emit);
      case DeleteMessageRequested():
        await _onDeleteMessageRequested(event, emit);
      case RealtimeMessageReceived():
        await _onRealtimeMessageReceived(event, emit);
    }
  }

  void _onResetMessagesRequested(
    ResetMessagesRequested event,
    Emitter<MessagesState> emit,
  ) {
    unawaited(_messageRuntimeService.disconnect());
    emit(const MessagesInitialState());
  }

  Future<void> _onLoadMessagesRequested(
    LoadMessagesRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();

    if (trimmedChannelId.isEmpty) {
      emit(
        switch (state) {
          final MessagesLoadedDataState loadedState =>
            MessagesValidationFailedState(
              issue: MessagesValidationIssue.channelSelectionRequired,
              messages: loadedState.messages,
              channelId: loadedState.channelId,
              authorDisplayNamesByUserId:
                  loadedState.authorDisplayNamesByUserId,
            ),
          _ => MessagesExceptionState(
              error: Exception("Messages must be loaded before validation."),
            ),
        },
      );
      return;
    }

    final currentState = _loadedStateOrNull(state);
    final existingDisplayNamesByUserId = switch (currentState) {
      MessagesLoadedDataState(:final authorDisplayNamesByUserId) =>
        authorDisplayNamesByUserId,
      _ => const <String, String?>{},
    };
    emit(const MessagesLoadingState());

    if (currentState?.channelId != trimmedChannelId) {
      final connectSessionResult = await _textSessionRepo.createOne(
        command: ConnectTextSessionCommand(channelId: trimmedChannelId),
      );

      final connectionResult = switch (connectSessionResult) {
        Ok<TextConnectSession>(:final value) =>
          await _messageRuntimeService.connect(
            livekitUrl: value.livekitUrl,
            accessToken: value.accessToken,
          ),
        Error<TextConnectSession>(:final error) => Error<void>(error),
      };

      if (connectionResult case Error<void>(:final error)) {
        emit(MessagesExceptionState(error: error));
        return;
      }
    }

    final listMessagesResult = await _messageRepo.getMany(
      query: GetMessagesQuery(
        channelId: trimmedChannelId,
      ),
    );

    switch (listMessagesResult) {
      case Ok<Iterable<Message>>(:final value):
        final messages = value.toList();
        final authorDisplayNamesByUserId = await _loadAuthorDisplayNames(
          messages,
          existingDisplayNamesByUserId: existingDisplayNamesByUserId,
        );
        emit(MessagesLoadedState(
          messages: messages,
          channelId: trimmedChannelId,
          authorDisplayNamesByUserId: authorDisplayNamesByUserId,
        ));
      case Error<Iterable<Message>>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onCreateMessageRequested(
    CreateMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final trimmedMessageContent = event.messageContent.trim();
    final loadedState = _loadedStateOrNull(state);
    final existingDisplayNamesByUserId = switch (loadedState) {
      MessagesLoadedDataState(:final authorDisplayNamesByUserId) =>
        authorDisplayNamesByUserId,
      _ => const <String, String?>{},
    };
    final currentMessages = loadedState?.messages ?? const <Message>[];
    final currentChannelId = loadedState?.channelId ?? "";

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: currentMessages,
        channelId: currentChannelId,
        authorDisplayNamesByUserId: existingDisplayNamesByUserId,
      ));
      return;
    }

    if (trimmedMessageContent.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.messageContentRequired,
        messages: currentMessages,
        channelId: trimmedChannelId,
        authorDisplayNamesByUserId: existingDisplayNamesByUserId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final realtimeResult = await _messageRuntimeService.sendTextMessage(
      channelId: trimmedChannelId,
      content: trimmedMessageContent,
    );

    if (realtimeResult case Error<void>(:final error)) {
      emit(MessagesExceptionState(error: error));
      return;
    }

    final createMessageResult = await _messageRepo.createOne(
      command: CreateMessageCommand(
        channelId: trimmedChannelId,
        content: trimmedMessageContent,
        mentionedUserId: event.mentionedUserId,
      ),
    );

    switch (createMessageResult) {
      case Ok<Message>(:final value):
        final messages = List<Message>.from(currentMessages)..add(value);
        final authorDisplayNamesByUserId = await _loadAuthorDisplayNames(
          messages,
          existingDisplayNamesByUserId: existingDisplayNamesByUserId,
        );
        emit(MessagesLoadedState(
          messages: messages,
          channelId: trimmedChannelId,
          authorDisplayNamesByUserId: authorDisplayNamesByUserId,
        ));
      case Error<Message>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onUpdateMessageRequested(
    UpdateMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final trimmedMessageContent = event.messageContent.trim();
    final loadedState = switch (state) {
      final MessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(MessagesExceptionState(
        error: Exception("Messages must be loaded before updating a message."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: loadedState.messages,
        channelId: loadedState.channelId,
        authorDisplayNamesByUserId: loadedState.authorDisplayNamesByUserId,
      ));
      return;
    }

    if (trimmedMessageContent.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.updatedContentRequired,
        messages: loadedState.messages,
        channelId: trimmedChannelId,
        authorDisplayNamesByUserId: loadedState.authorDisplayNamesByUserId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final updateMessageResult = await _messageRepo.updateOne(
      command: UpdateMessageCommand(
        channelId: trimmedChannelId,
        messageId: event.messageId,
        content: trimmedMessageContent,
      ),
    );

    switch (updateMessageResult) {
      case Ok<Message>(:final value):
        final messages = loadedState.messages
            .map(
              (message) => message.id == value.id ? value : message,
            )
            .toList();
        final authorDisplayNamesByUserId = await _loadAuthorDisplayNames(
          messages,
          existingDisplayNamesByUserId: loadedState.authorDisplayNamesByUserId,
        );
        emit(MessagesLoadedState(
          messages: messages,
          channelId: trimmedChannelId,
          authorDisplayNamesByUserId: authorDisplayNamesByUserId,
        ));
      case Error<Message>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onDeleteMessageRequested(
    DeleteMessageRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final loadedState = switch (state) {
      final MessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(MessagesExceptionState(
        error: Exception("Messages must be loaded before deleting a message."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(MessagesValidationFailedState(
        issue: MessagesValidationIssue.channelSelectionRequired,
        messages: loadedState.messages,
        channelId: loadedState.channelId,
        authorDisplayNamesByUserId: loadedState.authorDisplayNamesByUserId,
      ));
      return;
    }

    emit(const MessagesLoadingState());

    final deleteMessageResult = await _messageRepo.deleteOne(
      command: DeleteMessageCommand(
        channelId: trimmedChannelId,
        messageId: event.messageId,
      ),
    );

    switch (deleteMessageResult) {
      case Ok<void>():
        final messages = loadedState.messages
            .where((message) => message.id != event.messageId)
            .toList();
        final authorDisplayNamesByUserId = await _loadAuthorDisplayNames(
          messages,
          existingDisplayNamesByUserId: loadedState.authorDisplayNamesByUserId,
        );
        emit(MessagesLoadedState(
          messages: messages,
          channelId: trimmedChannelId,
          authorDisplayNamesByUserId: authorDisplayNamesByUserId,
        ));
      case Error<void>(:final error):
        emit(MessagesExceptionState(error: error));
    }
  }

  Future<void> _onRealtimeMessageReceived(
    RealtimeMessageReceived event,
    Emitter<MessagesState> emit,
  ) async {
    final loadedState = switch (state) {
      final MessagesLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(MessagesExceptionState(
        error: Exception(
          "Messages must be loaded before handling realtime messages.",
        ),
      ));
      return;
    }

    if (loadedState.channelId != event.channelId) {
      return;
    }

    final trimmedContent = event.content.trim();
    if (trimmedContent.isEmpty) {
      return;
    }

    final messages = List<Message>.from(loadedState.messages)
      ..add(
        Message(
          id: "rt-${DateTime.now().microsecondsSinceEpoch}",
          channelId: event.channelId,
          authorUserId: event.authorUserId,
          content: trimmedContent,
        ),
      );

    final authorDisplayNamesByUserId = await _loadAuthorDisplayNames(
      messages,
      existingDisplayNamesByUserId: loadedState.authorDisplayNamesByUserId,
    );
    emit(MessagesLoadedState(
      messages: messages,
      channelId: loadedState.channelId,
      authorDisplayNamesByUserId: authorDisplayNamesByUserId,
    ));
  }

  MessagesLoadedDataState? _loadedStateOrNull(MessagesState state) {
    return switch (state) {
      MessagesLoadedDataState() => state,
      _ => null,
    };
  }

  Future<Map<String, String?>> _loadAuthorDisplayNames(
    List<Message> messages, {
    Map<String, String?> existingDisplayNamesByUserId =
        const <String, String?>{},
  }) async {
    final subjects = messages
        .map((message) => message.authorUserId)
        .where((userId) => userId.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    final authorDisplayNamesByUserId = <String, String?>{};
    for (final userId in subjects) {
      if (existingDisplayNamesByUserId.containsKey(userId)) {
        authorDisplayNamesByUserId[userId] =
            existingDisplayNamesByUserId[userId];
        continue;
      }

      final profileResult = await _profileRepo.getOne(
        query: GetUserQuery(userId: userId),
      );

      final displayName = switch (profileResult) {
        Ok<UserProfile>(:final value) => value.displayName?.trim(),
        Error<UserProfile>() => null,
      };

      authorDisplayNamesByUserId[userId] =
          displayName != null && displayName.isNotEmpty ? displayName : null;
    }

    return authorDisplayNamesByUserId;
  }

  @override
  Future<void> close() async {
    await _runtimeTextSubscription?.cancel();
    await _messageRuntimeService.disconnect();
    return super.close();
  }
}
