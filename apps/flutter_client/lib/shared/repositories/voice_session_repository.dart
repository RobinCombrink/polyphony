import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";

class VoiceSessionRepository implements VoiceSessionRepo {
  const VoiceSessionRepository({
    required VoiceSessionService voiceSessionService,
  }) : _voiceSessionService = voiceSessionService;

  final VoiceSessionService _voiceSessionService;

  @override
  Future<Result<VoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    final serviceResult = await _voiceSessionService.connectVoiceSession(
      baseUrl: baseUrl,
      channelId: channelId,
    );

    return switch (serviceResult) {
      Ok<ApiVoiceConnectSession>(:final value) =>
        Ok<VoiceConnectSession>(value.toDomainModel()),
      Error<ApiVoiceConnectSession>(:final error) =>
        Error<VoiceConnectSession>(error),
    };
  }

  @override
  Future<Result<void>> disconnectVoiceSession({
    required String baseUrl,
    required String channelId,
  }) {
    return _voiceSessionService.disconnectVoiceSession(
      baseUrl: baseUrl,
      channelId: channelId,
    );
  }
}
