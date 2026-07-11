import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:stream_transform/stream_transform.dart";

part "message_search_event.dart";
part "message_search_state.dart";

EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class MessageSearchBloc extends Bloc<MessageSearchEvent, MessageSearchState> {
  MessageSearchBloc({
    required MessageRepo messageRepo,
  })  : _messageRepo = messageRepo,
        super(const MessageSearchInitialState()) {
    on<MessageSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(const Duration(milliseconds: 300)),
    );
    on<MessageSearchCleared>(_onCleared);
  }

  final MessageRepo _messageRepo;

  Future<void> _onQueryChanged(
    MessageSearchQueryChanged event,
    Emitter<MessageSearchState> emit,
  ) async {
    final trimmedQuery = event.query.trim();
    if (trimmedQuery.isEmpty) {
      emit(const MessageSearchInitialState());
      return;
    }

    emit(const MessageSearchLoadingState());

    final result = await _messageRepo.getMany(
      query: GetMessagesQuery(
        channelId: event.channelId,
        filter: MessageFilter(searchQuery: trimmedQuery),
      ),
    );

    switch (result) {
      case Ok<Iterable<Message>>(:final value):
        emit(MessageSearchLoadedState(results: value.toList()));
      case Error<Iterable<Message>>(:final error):
        emit(MessageSearchExceptionState(error: error));
    }
  }

  void _onCleared(
    MessageSearchCleared event,
    Emitter<MessageSearchState> emit,
  ) {
    emit(const MessageSearchInitialState());
  }
}
