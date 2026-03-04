final class AuthenticationRequiredException implements Exception {
  const AuthenticationRequiredException({
    this.message = "Auth token is required.",
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

final class ApiRequestException implements Exception {
  const ApiRequestException({
    required this.operation,
    required this.statusCode,
    required this.responseBody,
  });

  final String operation;
  final int statusCode;
  final String responseBody;

  @override
  String toString() {
    return "Failed to $operation: $statusCode $responseBody";
  }
}

final class RuntimeConnectionException implements Exception {
  const RuntimeConnectionException({
    required this.operation,
    required this.cause,
  });

  final String operation;
  final Exception cause;

  @override
  String toString() {
    return "Runtime connection $operation failed: $cause";
  }
}

enum VoiceSessionOperation {
  load,
  connect,
  disconnect,
  setMute,
  setDeafen,
  toggleScreenShare,
  refreshParticipants,
}

enum VoiceSessionPreconditionIssue {
  loadedStateRequired,
}

final class VoiceSessionPreconditionException implements Exception {
  const VoiceSessionPreconditionException({
    required this.operation,
    required this.issue,
  });

  final VoiceSessionOperation operation;
  final VoiceSessionPreconditionIssue issue;
}
