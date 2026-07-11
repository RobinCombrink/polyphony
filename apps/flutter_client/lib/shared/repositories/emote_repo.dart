import "package:polyphony_flutter_client/shared/models/emote.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class ListEmotesQuery {
  const ListEmotesQuery();
}

abstract interface class EmoteRepo
    with RepositoryGetMany<Emote, ListEmotesQuery> {}
