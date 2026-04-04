import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestEmoteService extends RestRequestServiceBase implements EmoteService {
  RestEmoteService({required super.dio});

  List<Emote>? _cachedEmotes;

  @override
  Future<Result<List<Emote>>> listEmotes() async {
    if (_cachedEmotes != null) {
      return Ok<List<Emote>>(_cachedEmotes!);
    }

    final result = await performListRequest<Emote>(
      endpoint: "/api/v1/emotes",
      operation: "list emotes",
      decodeItem: (json) => Emote(
        id: json["id"] as String,
        shortcode: json["shortcode"] as String,
        emojiChar: json["emoji_char"] as String,
      ),
    );

    if (result case Ok<List<Emote>>(:final value)) {
      _cachedEmotes = value;
    }

    return result;
  }
}
