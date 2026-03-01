import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class ConnectTextSessionCommand {
  const ConnectTextSessionCommand({
    required this.channelId,
  });

  final String channelId;
}

abstract interface class TextSessionRepo
    with RepositoryCreateOne<TextConnectSession, ConnectTextSessionCommand> {}
