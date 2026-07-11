import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/emote.dart";
import "package:polyphony_flutter_client/shared/repositories/emote_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "emote_catalog_event.dart";
part "emote_catalog_state.dart";

class EmoteCatalogBloc extends Bloc<EmoteCatalogEvent, EmoteCatalogState> {
  EmoteCatalogBloc({
    required EmoteRepo emoteRepo,
  })  : _emoteRepo = emoteRepo,
        super(const EmoteCatalogInitialState()) {
    on<EmoteCatalogLoadRequested>(_onLoadRequested);
  }

  final EmoteRepo _emoteRepo;

  Future<void> _onLoadRequested(
    EmoteCatalogLoadRequested event,
    Emitter<EmoteCatalogState> emit,
  ) async {
    emit(const EmoteCatalogLoadingState());

    final result = await _emoteRepo.getMany(
      query: const ListEmotesQuery(),
    );

    switch (result) {
      case Ok<Iterable<Emote>>(:final value):
        emit(EmoteCatalogLoadedState(emotes: value.toList()));
      case Error<Iterable<Emote>>(:final error):
        emit(EmoteCatalogExceptionState(error: error));
    }
  }
}
