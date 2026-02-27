import "package:polyphony_flutter_client/shared/result/result.dart";

class RuntimeTextMessage {
  const RuntimeTextMessage({
    required this.channelId,
    required this.authorSubject,
    required this.content,
  });

  final String channelId;
  final String authorSubject;
  final String content;
}

abstract interface class VoiceRuntimeService {
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  });

  Future<Result<void>> disconnect();

  Iterable<String> currentParticipantSubjects();

  Stream<RuntimeTextMessage> textMessages();

  Future<Result<void>> sendTextMessage({
    required String channelId,
    required String content,
  });
}
