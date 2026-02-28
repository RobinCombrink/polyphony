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
  Future<Result<Iterable<VoiceSession>>> getMany({
    required GetVoiceSessionsQuery query,
  }) async {
    final serviceResult = await _voiceSessionService.listVoiceSessions(
      channelId: query.channelId,
    );

    return switch (serviceResult) {
      Ok<List<ApiVoiceSession>>(:final value) => Ok<Iterable<VoiceSession>>(
          value.map((voiceSession) => voiceSession.toDomainModel()),
        ),
      Error<List<ApiVoiceSession>>(:final error) =>
        Error<Iterable<VoiceSession>>(error),
    };
  }

  @override
  Future<Result<VoiceConnectSession>> createOne({
    required ConnectVoiceSessionCommand command,
  }) async {
    final serviceResult = await _voiceSessionService.connectVoiceSession(
      channelId: command.channelId,
    );

    return switch (serviceResult) {
      Ok<ApiVoiceConnectSession>(:final value) =>
        Ok<VoiceConnectSession>(value.toDomainModel()),
      Error<ApiVoiceConnectSession>(:final error) =>
        Error<VoiceConnectSession>(error),
    };
  }

  @override
  Future<Result<void>> updateOne({
    required SetSelfVoiceSessionMuteCommand command,
  }) {
    return _voiceSessionService.setSelfMuted(
      channelId: command.channelId,
      isMuted: command.isMuted,
    );
  }

  @override
  Future<Result<void>> deleteOne({
    required DisconnectVoiceSessionCommand command,
  }) {
    return _voiceSessionService.disconnectVoiceSession(
      channelId: command.channelId,
    );
  }
}
