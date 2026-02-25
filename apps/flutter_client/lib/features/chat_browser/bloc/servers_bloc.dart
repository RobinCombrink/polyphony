import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "servers_event.dart";
part "servers_state.dart";

class ServersBloc extends Bloc<ServersEvent, ServersState> {
  ServersBloc({required ServerRepo serverRepo})
      : _serverRepo = serverRepo,
        super(const ServersInitialState()) {
    on<LoadServersRequested>(_onLoadServersRequested);
    on<CreateServerRequested>(_onCreateServerRequested);
  }

  final ServerRepo _serverRepo;

  Future<void> _onLoadServersRequested(
    LoadServersRequested event,
    Emitter<ServersState> emit,
  ) async {
    emit(ServersLoadingState(servers: state.servers));

    final listServersResult = await _serverRepo.listServers(
      baseUrl: event.baseUrl.trim(),
    );

    switch (listServersResult) {
      case Ok<List<Server>>(:final value):
        emit(ServersLoadedState(servers: value));
      case Error<List<Server>>(:final error):
        emit(ServersExceptionState(error: error, servers: state.servers));
    }
  }

  Future<void> _onCreateServerRequested(
    CreateServerRequested event,
    Emitter<ServersState> emit,
  ) async {
    final trimmedServerName = event.serverName.trim();

    if (trimmedServerName.isEmpty) {
      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.serverNameRequired,
        servers: state.servers,
      ));
      return;
    }

    emit(ServersLoadingState(servers: state.servers));

    final createServerResult = await _serverRepo.createServer(
      baseUrl: event.baseUrl.trim(),
      name: trimmedServerName,
    );

    switch (createServerResult) {
      case Ok<Server>():
        final listServersResult = await _serverRepo.listServers(
          baseUrl: event.baseUrl.trim(),
        );
        switch (listServersResult) {
          case Ok<List<Server>>(:final value):
            emit(ServersLoadedState(servers: value));
          case Error<List<Server>>(:final error):
            emit(ServersExceptionState(error: error, servers: state.servers));
        }
      case Error<Server>(:final error):
        emit(ServersExceptionState(error: error, servers: state.servers));
    }
  }
}
