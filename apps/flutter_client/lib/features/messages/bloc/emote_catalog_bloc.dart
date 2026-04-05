import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";

part "emote_catalog_event.dart";
part "emote_catalog_state.dart";

class EmoteCatalogBloc extends Bloc<EmoteCatalogEvent, EmoteCatalogState> {
  EmoteCatalogBloc({
    required EmoteService emoteService,
  })  : _emoteService = emoteService,
        super(const EmoteCatalogInitialState()) {
    on<EmoteCatalogLoadRequested>(_onLoadRequested);
  }

  final EmoteService _emoteService;

  Future<void> _onLoadRequested(
    EmoteCatalogLoadRequested event,
    Emitter<EmoteCatalogState> emit,
  ) async {
    emit(const EmoteCatalogLoadingState());

    final result = await _emoteService.listEmotes();

    switch (result) {
      case Ok<List<Emote>>(:final value):
        emit(EmoteCatalogLoadedState(emotes: value));
      case Error<List<Emote>>(:final error):
        emit(EmoteCatalogExceptionState(error: error));
    }
  }
}
