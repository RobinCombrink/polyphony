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
    on<SelectServerRequested>(_onSelectServerRequested);
    on<AddServerMemberRequested>(_onAddServerMemberRequested);
  }

  final ServerRepo _serverRepo;

  Future<void> _onLoadServersRequested(
    LoadServersRequested event,
    Emitter<ServersState> emit,
  ) async {
    final previousLoadedState = _loadedStateOrNull(state);

    emit(const ServersLoadingState());

    final listServersResult = await _serverRepo.listServers(
      baseUrl: event.baseUrl.trim(),
    );

    switch (listServersResult) {
      case Ok<List<Server>>(:final value):
        final selectedServerId = value.any(
          (server) => server.id == previousLoadedState?.selectedServerId,
        )
            ? previousLoadedState?.selectedServerId
            : null;

        emit(ServersLoadedState(
          servers: value,
          selectedServerId: selectedServerId,
        ));
      case Error<List<Server>>(:final error):
        emit(ServersExceptionState(error: error));
    }
  }

  Future<void> _onCreateServerRequested(
    CreateServerRequested event,
    Emitter<ServersState> emit,
  ) async {
    final trimmedServerName = event.serverName.trim();
    final loadedState = _loadedStateOrNull(state);

    if (trimmedServerName.isEmpty) {
      if (loadedState == null) {
        emit(ServersExceptionState(
          error: Exception("Servers must be loaded before creating a server."),
        ));
        return;
      }

      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.serverNameRequired,
        servers: loadedState.servers,
        selectedServerId: loadedState.selectedServerId,
      ));
      return;
    }

    emit(const ServersLoadingState());

    final createServerResult = await _serverRepo.createServer(
      baseUrl: event.baseUrl.trim(),
      name: trimmedServerName,
    );

    switch (createServerResult) {
      case Ok<Server>(:final value):
        final createdServer = value;
        final listServersResult = await _serverRepo.listServers(
          baseUrl: event.baseUrl.trim(),
        );
        switch (listServersResult) {
          case Ok<List<Server>>(:final value):
            final servers = value;
            emit(ServersLoadedState(
              servers: servers,
              selectedServerId: servers.any(
                (server) => server.id == createdServer.id,
              )
                  ? createdServer.id
                  : null,
            ));
          case Error<List<Server>>(:final error):
            emit(ServersExceptionState(error: error));
        }
      case Error<Server>(:final error):
        emit(ServersExceptionState(error: error));
    }
  }

  void _onSelectServerRequested(
    SelectServerRequested event,
    Emitter<ServersState> emit,
  ) {
    final loadedState = _loadedStateOrNull(state);
    if (loadedState == null) {
      return;
    }

    final trimmedServerId = event.serverId.trim();
    final selectedServerId = loadedState.servers.any(
      (server) => server.id == trimmedServerId,
    )
        ? trimmedServerId
        : null;

    emit(ServersLoadedState(
      servers: loadedState.servers,
      selectedServerId: selectedServerId,
    ));
  }

  Future<void> _onAddServerMemberRequested(
    AddServerMemberRequested event,
    Emitter<ServersState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(ServersExceptionState(
        error: Exception("Servers must be loaded before adding a member."),
      ));
      return;
    }

    final trimmedServerId = event.serverId.trim();
    final trimmedUserSubject = event.userSubject.trim();

    if (trimmedServerId.isEmpty ||
        !loadedState.servers.any((server) => server.id == trimmedServerId)) {
      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.serverSelectionRequired,
        servers: loadedState.servers,
        selectedServerId: loadedState.selectedServerId,
      ));
      return;
    }

    if (trimmedUserSubject.isEmpty) {
      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.userSubjectRequired,
        servers: loadedState.servers,
        selectedServerId: loadedState.selectedServerId,
      ));
      return;
    }

    emit(const ServersLoadingState());

    final addMemberResult = await _serverRepo.addServerMember(
      baseUrl: event.baseUrl.trim(),
      serverId: trimmedServerId,
      userSubject: trimmedUserSubject,
    );

    switch (addMemberResult) {
      case Ok<void>():
        final listServersResult = await _serverRepo.listServers(
          baseUrl: event.baseUrl.trim(),
        );

        switch (listServersResult) {
          case Ok<List<Server>>(:final value):
            emit(ServersLoadedState(
              servers: value,
              selectedServerId: value.any(
                (server) => server.id == trimmedServerId,
              )
                  ? trimmedServerId
                  : null,
            ));
          case Error<List<Server>>(:final error):
            emit(ServersExceptionState(error: error));
        }
      case Error<void>(:final error):
        emit(ServersExceptionState(error: error));
    }
  }

  ServersLoadedDataState? _loadedStateOrNull(ServersState state) {
    return switch (state) {
      ServersLoadedDataState() => state,
      _ => null,
    };
  }
}
