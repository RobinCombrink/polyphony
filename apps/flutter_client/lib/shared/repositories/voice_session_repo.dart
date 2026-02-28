import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class ConnectVoiceSessionCommand {
  const ConnectVoiceSessionCommand({
    required this.channelId,
  });

  final String channelId;
}

class GetVoiceSessionsQuery {
  const GetVoiceSessionsQuery({
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

class SetSelfVoiceSessionMuteCommand {
  const SetSelfVoiceSessionMuteCommand({
    required this.channelId,
    required this.isMuted,
  });

  final String channelId;
  final bool isMuted;
}

abstract interface class VoiceSessionRepo
    with
        RepositoryGetMany<VoiceSession, GetVoiceSessionsQuery>,
        RepositoryCreateOne<VoiceConnectSession, ConnectVoiceSessionCommand>,
        RepositoryUpdateOne<void, SetSelfVoiceSessionMuteCommand>,
        RepositoryDeleteOne<DisconnectVoiceSessionCommand> {}
