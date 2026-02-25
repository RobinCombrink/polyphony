part of "servers_bloc.dart";

enum ServersValidationIssue {
  serverNameRequired,
}

sealed class ServersState {
  const ServersState({required this.servers});

  final List<Server> servers;

  bool get isLoading => this is ServersLoadingState;
}

final class ServersInitialState extends ServersState {
  const ServersInitialState() : super(servers: const <Server>[]);
}

final class ServersLoadingState extends ServersState {
  const ServersLoadingState({required super.servers});
}

final class ServersLoadedState extends ServersState {
  const ServersLoadedState({required super.servers});
}

final class ServersValidationFailedState extends ServersState {
  const ServersValidationFailedState({
    required this.issue,
    required super.servers,
  });

  final ServersValidationIssue issue;
}

final class ServersExceptionState extends ServersState {
  const ServersExceptionState({
    required this.error,
    required super.servers,
  });

  final Exception error;
}
