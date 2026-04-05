part of "emote_catalog_bloc.dart";

sealed class EmoteCatalogEvent {
  const EmoteCatalogEvent();
}

final class EmoteCatalogLoadRequested extends EmoteCatalogEvent {
  const EmoteCatalogLoadRequested();
}
