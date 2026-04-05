part of "emote_catalog_bloc.dart";

sealed class EmoteCatalogState {
  const EmoteCatalogState();
}

final class EmoteCatalogInitialState extends EmoteCatalogState {
  const EmoteCatalogInitialState();
}

final class EmoteCatalogLoadingState extends EmoteCatalogState {
  const EmoteCatalogLoadingState();
}

final class EmoteCatalogLoadedState extends EmoteCatalogState {
  const EmoteCatalogLoadedState({
    required this.emotes,
  });

  final List<Emote> emotes;
}

final class EmoteCatalogExceptionState extends EmoteCatalogState {
  const EmoteCatalogExceptionState({
    required this.error,
  });

  final Exception error;
}
