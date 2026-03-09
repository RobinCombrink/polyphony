import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";

final class RestVoiceSessionService extends RestRequestServiceBase
    implements VoiceSessionService {
  RestVoiceSessionService({
    required super.dio,
  });

  @override
  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String channelId,
    String? participantInstanceId,
  }) {
    final trimmedParticipantInstanceId = participantInstanceId?.trim();

    return performPostRequest<ApiVoiceConnectSession>(
      endpoint: "/api/v1/channels/$channelId/session",
      operation: "connect voice session",
      body: <String, dynamic>{
        "session_type": "voice",
        if (trimmedParticipantInstanceId != null &&
            trimmedParticipantInstanceId.isNotEmpty)
          "participant_instance_id": trimmedParticipantInstanceId,
      },
      expectedStatusCode: 200,
      decodeItem: ApiVoiceConnectSession.fromJson,
    );
  }
}
