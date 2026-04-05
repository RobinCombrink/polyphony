import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";
import "package:stream_transform/stream_transform.dart";

part "message_search_event.dart";
part "message_search_state.dart";

EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class MessageSearchBloc extends Bloc<MessageSearchEvent, MessageSearchState> {
  MessageSearchBloc({
    required MessageService messageService,
  })  : _messageService = messageService,
        super(const MessageSearchInitialState()) {
    on<MessageSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(const Duration(milliseconds: 300)),
    );
    on<MessageSearchCleared>(_onCleared);
  }

  final MessageService _messageService;

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

    final result = await _messageService.searchMessages(
      channelId: event.channelId.value,
      query: trimmedQuery,
    );

    switch (result) {
      case Ok<List<ApiMessage>>(:final value):
        emit(
          MessageSearchLoadedState(
            results:
                value.map((apiMessage) => apiMessage.toDomainModel()).toList(),
          ),
        );
      case Error<List<ApiMessage>>(:final error):
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
