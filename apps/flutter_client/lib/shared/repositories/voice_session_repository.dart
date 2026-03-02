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
  Future<Result<VoiceConnectSession>> createOne({
    required ConnectVoiceSessionCommand command,
  }) async {
    final serviceResult = await _voiceSessionService.connectVoiceSession(
      channelId: command.channelId,
      participantInstanceId: command.participantInstanceId,
    );

    return switch (serviceResult) {
      Ok<ApiVoiceConnectSession>(:final value) =>
        Ok<VoiceConnectSession>(value.toDomainModel()),
      Error<ApiVoiceConnectSession>(:final error) =>
        Error<VoiceConnectSession>(error),
    };
  }
}
