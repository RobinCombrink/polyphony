import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/text_session_service.dart";

class TextSessionRepository implements TextSessionRepo {
  const TextSessionRepository({
    required TextSessionService textSessionService,
  }) : _textSessionService = textSessionService;

  final TextSessionService _textSessionService;

  @override
  Future<Result<TextConnectSession>> createOne({
    required ConnectTextSessionCommand command,
  }) async {
    final serviceResult = await _textSessionService.connectTextSession(
      channelId: command.channelId,
    );

    return switch (serviceResult) {
      Ok<ApiTextConnectSession>(:final value) =>
        Ok<TextConnectSession>(value.toDomainModel()),
      Error<ApiTextConnectSession>(:final error) =>
        Error<TextConnectSession>(error),
    };
  }
}
