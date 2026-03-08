import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/websocket/web_socket_notification_runtime_service.dart";

void main() {
  test("parses mentioned event with required fields", () {
    final parsed = parseRuntimeNotificationEventPayload(
      <String, dynamic>{
        "event_type": "mentioned",
        "server_id": "srv-1",
        "server_name": "Server",
        "channel_id": "chn-1",
        "channel_name": "general",
        "message_id": "msg-1",
      },
    );

    expect(parsed, isA<MentionedRuntimeNotificationEvent>());
    expect((parsed as MentionedRuntimeNotificationEvent).messageId, "msg-1");
  });

  test("parses friend_joined_voice event with required fields", () {
    final parsed = parseRuntimeNotificationEventPayload(
      <String, dynamic>{
        "event_type": "friend_joined_voice",
        "server_id": "srv-1",
        "server_name": "Server",
        "channel_id": "vch-1",
        "channel_name": "Voice lobby",
        "joined_user_id": "usr-2",
        "joined_user_display_name": "Olivia",
      },
    );

    expect(parsed, isA<FriendJoinedVoiceRuntimeNotificationEvent>());
    final voiceEvent = parsed as FriendJoinedVoiceRuntimeNotificationEvent;
    expect(voiceEvent.joinedUserId, "usr-2");
    expect(voiceEvent.joinedUserDisplayName, "Olivia");
  });

  test("rejects friend_joined_voice with missing joined_user_display_name", () {
    final parsed = parseRuntimeNotificationEventPayload(
      <String, dynamic>{
        "event_type": "friend_joined_voice",
        "server_id": "srv-1",
        "server_name": "Server",
        "channel_id": "vch-1",
        "channel_name": "Voice lobby",
        "joined_user_id": "usr-2",
      },
    );

    expect(parsed, isNull);
  });

  test("rejects mentioned event with empty message_id", () {
    final parsed = parseRuntimeNotificationEventPayload(
      <String, dynamic>{
        "event_type": "mentioned",
        "server_id": "srv-1",
        "server_name": "Server",
        "channel_id": "chn-1",
        "channel_name": "general",
        "message_id": "   ",
      },
    );

    expect(parsed, isNull);
  });
}
