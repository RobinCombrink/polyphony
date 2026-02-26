part of "servers_bloc.dart";

enum ServersValidationIssue {
  serverNameRequired,
  serverSelectionRequired,
  userSubjectRequired,
}

sealed class ServersState {
  const ServersState();
}

final class ServersInitialState extends ServersState {
  const ServersInitialState();
}

final class ServersLoadingState extends ServersState {
  const ServersLoadingState();
}

sealed class ServersLoadedDataState extends ServersState {
  const ServersLoadedDataState({
    required this.servers,
    required this.selectedServerId,
  });

  final List<Server> servers;
  final String? selectedServerId;
}

final class ServersLoadedState extends ServersLoadedDataState {
  const ServersLoadedState({
    required super.servers,
    required super.selectedServerId,
  });
}

final class ServersValidationFailedState extends ServersLoadedDataState {
  const ServersValidationFailedState({
    required this.issue,
    required super.servers,
    required super.selectedServerId,
  });

  final ServersValidationIssue issue;
}

final class ServersExceptionState extends ServersState {
  const ServersExceptionState({required this.error});

  final Exception error;
}
