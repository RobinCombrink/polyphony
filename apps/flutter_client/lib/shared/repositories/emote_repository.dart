import "package:polyphony_flutter_client/shared/repositories/emote_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";

class EmoteRepository implements EmoteRepo {
  const EmoteRepository({required EmoteService emoteService})
      : _emoteService = emoteService;

  final EmoteService _emoteService;

  @override
  Future<Result<Iterable<Emote>>> getMany({
    required ListEmotesQuery query,
  }) {
    return _emoteService.listEmotes();
  }
}
