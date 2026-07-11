import "package:polyphony_flutter_client/shared/models/emote.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

export "package:polyphony_flutter_client/shared/models/emote.dart";

abstract interface class EmoteService {
  Future<Result<List<Emote>>> listEmotes();
}
