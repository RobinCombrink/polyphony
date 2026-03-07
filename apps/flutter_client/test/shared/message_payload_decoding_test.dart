import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";

void main() {
  group("ApiMessage.fromJson", () {
    test("decodes backend enum-tagged message payload", () {
      final decoded = ApiMessage.fromJson(<String, dynamic>{
        "type": "mentioned",
        "details": <String, dynamic>{
          "common": <String, dynamic>{
            "id": "message-1",
            "channel_id": "channel-1",
            "author_user_id": "author-1",
            "content": "hello",
          },
          "mentioned_user_id": "mentioned-1",
        },
      });

      expect(decoded.id, "message-1");
      expect(decoded.channelId, "channel-1");
      expect(decoded.authorUserId, "author-1");
      expect(decoded.content, "hello");
    });

    test("rejects legacy flat message payload", () {
      expect(
        () => ApiMessage.fromJson(<String, dynamic>{
          "id": "message-2",
          "channel_id": "channel-2",
          "author_user_id": "author-2",
          "content": "legacy",
        }),
        throwsFormatException,
      );
    });
  });

  group("Message.fromJson", () {
    test("decodes backend enum-tagged message payload", () {
      final decoded = Message.fromJson(<String, dynamic>{
        "type": "regular",
        "details": <String, dynamic>{
          "common": <String, dynamic>{
            "id": "message-3",
            "channel_id": "channel-3",
            "author_user_id": "author-3",
            "content": "domain",
          },
        },
      });

      expect(decoded.id, "message-3");
      expect(decoded.channelId, "channel-3");
      expect(decoded.authorUserId, "author-3");
      expect(decoded.content, "domain");
    });
  });
}
