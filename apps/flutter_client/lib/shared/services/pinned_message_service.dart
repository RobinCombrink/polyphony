import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/pinned_message.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

export "package:polyphony_flutter_client/shared/models/pinned_message.dart";

abstract interface class PinnedMessageService {
  Future<Result<void>> pinMessage({
    required ServerId serverId,
    required MessageId messageId,
  });

  Future<Result<void>> unpinMessage({
    required ServerId serverId,
    required MessageId messageId,
  });

  Future<Result<List<PinnedMessage>>> listPinnedMessages({
    required ServerId serverId,
  });
}
