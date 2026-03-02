import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class ConnectVoiceSessionCommand {
  const ConnectVoiceSessionCommand({
    required this.channelId,
    this.participantInstanceId,
  });

  final String channelId;
  final String? participantInstanceId;
}

abstract interface class VoiceSessionRepo
    with RepositoryCreateOne<VoiceConnectSession, ConnectVoiceSessionCommand> {}
