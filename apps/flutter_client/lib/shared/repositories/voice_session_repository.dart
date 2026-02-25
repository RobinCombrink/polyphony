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
  Future<Result<List<VoiceSession>>> listVoiceSessions({
    required String baseUrl,
    required String channelId,
  }) async {
    final serviceResult = await _voiceSessionService.listVoiceSessions(
      baseUrl: baseUrl,
      channelId: channelId,
    );

    return switch (serviceResult) {
      Ok<List<ApiVoiceSession>>(:final value) => Ok<List<VoiceSession>>(
          value.map((voiceSession) => voiceSession.toDomainModel()).toList(),
        ),
      Error<List<ApiVoiceSession>>(:final error) =>
        Error<List<VoiceSession>>(error),
    };
  }

  @override
  Future<Result<VoiceSession>> joinVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    final serviceResult = await _voiceSessionService.joinVoiceSession(
      baseUrl: baseUrl,
      channelId: channelId,
    );

    return switch (serviceResult) {
      Ok<ApiVoiceSession>(:final value) =>
        Ok<VoiceSession>(value.toDomainModel()),
      Error<ApiVoiceSession>(:final error) => Error<VoiceSession>(error),
    };
  }

  @override
  Future<Result<void>> leaveVoiceSession({
    required String baseUrl,
    required String channelId,
  }) {
    return _voiceSessionService.leaveVoiceSession(
      baseUrl: baseUrl,
      channelId: channelId,
    );
  }
}
