import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class ConnectVoiceSessionCommand {
  const ConnectVoiceSessionCommand({
    required this.channelId,
  });

  final String channelId;
}

class DisconnectVoiceSessionCommand {
  const DisconnectVoiceSessionCommand({
    required this.channelId,
  });

  final String channelId;
}

abstract interface class VoiceSessionRepo
    with
        RepositoryCreateOne<VoiceConnectSession, ConnectVoiceSessionCommand>,
        RepositoryDeleteOne<DisconnectVoiceSessionCommand> {}
