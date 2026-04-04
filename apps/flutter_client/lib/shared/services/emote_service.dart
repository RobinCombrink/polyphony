import "package:polyphony_flutter_client/shared/result/result.dart";

class Emote {
  const Emote({
    required this.id,
    required this.shortcode,
    required this.emojiChar,
  });

  final String id;
  final String shortcode;
  final String emojiChar;
}

abstract interface class EmoteService {
  Future<Result<List<Emote>>> listEmotes();
}
