import "package:collection/collection.dart";
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
    on<DeleteServerRequested>(_onDeleteServerRequested);
    on<UpdateServerNameRequested>(_onUpdateServerNameRequested);
    on<SelectServerRequested>(_onSelectServerRequested);
  }

  final ServerRepo _serverRepo;

  Future<void> _onLoadServersRequested(
    LoadServersRequested event,
    Emitter<ServersState> emit,
  ) async {
    final previousState = state;

    emit(const ServersLoadingState());

    final listServersResult = await _serverRepo.getMany(
      query: const GetServersQuery(),
    );

    switch (listServersResult) {
      case Ok<Iterable<Server>>(:final value):
        final servers = value.toList();

        emit(previousState.loadServers(servers: servers));
      case Error<Iterable<Server>>(:final error):
        emit(ServersExceptionState(error: error));
    }
  }

  Future<void> _onCreateServerRequested(
    CreateServerRequested event,
    Emitter<ServersState> emit,
  ) async {
    final trimmedServerName = event.serverName.trim();

    if (trimmedServerName.isEmpty) {
      emit(
        switch (state) {
          final ServersLoadedState loadedState => ServersValidationFailedState(
              issue: ServersValidationIssue.serverNameRequired,
              servers: loadedState.servers,
            ),
          _ => ServersExceptionState(
              error: Exception(
                "Servers must be loaded before creating a server.",
              ),
            ),
        },
      );
      return;
    }

    emit(const ServersLoadingState());

    final createServerResult = await _serverRepo.createOne(
      command: CreateServerCommand(
        name: trimmedServerName,
      ),
    );

    switch (createServerResult) {
      case Ok<Server>(:final value):
        final createdServer = value;
        final listServersResult = await _serverRepo.getMany(
          query: const GetServersQuery(),
        );
        switch (listServersResult) {
          case Ok<Iterable<Server>>(:final value):
            final servers = value.toList();
            emit(state.loadServers(servers: servers).selectServer(
                  incomingSelectedServer: createdServer,
                ));
          case Error<Iterable<Server>>(:final error):
            emit(ServersExceptionState(error: error));
        }
      case Error<Server>(:final error):
        emit(ServersExceptionState(error: error));
    }
  }

  Future<void> _onDeleteServerRequested(
    DeleteServerRequested event,
    Emitter<ServersState> emit,
  ) async {
    if (state case final ServersLoadedState state) {
      final trimmedServerId = event.serverId.trim();
      if (trimmedServerId.isEmpty ||
          !state.servers.any((server) => server.id == trimmedServerId)) {
        emit(ServersValidationFailedState(
          issue: ServersValidationIssue.serverSelectionRequired,
          servers: state.servers,
        ));
        return;
      }

      emit(const ServersLoadingState());

      final deleteServerResult = await _serverRepo.deleteOne(
        command: DeleteServerCommand(serverId: trimmedServerId),
      );

      switch (deleteServerResult) {
        case Ok<void>():
          final listServersResult = await _serverRepo.getMany(
            query: const GetServersQuery(),
          );

          switch (listServersResult) {
            case Ok<Iterable<Server>>(:final value):
              final servers = value.toList();

              emit(state.deleteServer(servers: servers));
            case Error<Iterable<Server>>(:final error):
              emit(ServersExceptionState(error: error));
          }
        case Error<void>(:final error):
          emit(ServersExceptionState(error: error));
      }

      return;
    }

    emit(ServersExceptionState(
      error: Exception("Servers must be loaded before deleting a server."),
    ));
  }

  Future<void> _onUpdateServerNameRequested(
    UpdateServerNameRequested event,
    Emitter<ServersState> emit,
  ) async {
    if (state case final ServersLoadedState state) {
      final trimmedServerId = event.serverId.trim();
      final trimmedName = event.name.trim();

      if (trimmedServerId.isEmpty ||
          !state.servers.any((server) => server.id == trimmedServerId)) {
        emit(ServersValidationFailedState(
          issue: ServersValidationIssue.serverSelectionRequired,
          servers: state.servers,
        ));
        return;
      }

      if (trimmedName.isEmpty) {
        emit(ServersValidationFailedState(
          issue: ServersValidationIssue.serverNameRequired,
          servers: state.servers,
        ));
        return;
      }

      emit(const ServersLoadingState());

      final updateResult = await _serverRepo.updateOne(
        command: UpdateServerNameCommand(
          serverId: trimmedServerId,
          name: trimmedName,
        ),
      );

      switch (updateResult) {
        case Ok<void>():
          final listServersResult = await _serverRepo.getMany(
            query: const GetServersQuery(),
          );

          switch (listServersResult) {
            case Ok<Iterable<Server>>(:final value):
              final servers = value.toList();
              final updatedServer = servers.firstWhereOrNull(
                (server) => server.id == trimmedServerId,
              );

              emit(state.loadServers(servers: servers).selectServer(
                    incomingSelectedServer: updatedServer,
                  ));
            case Error<Iterable<Server>>(:final error):
              emit(ServersExceptionState(error: error));
          }
        case Error<void>(:final error):
          emit(ServersExceptionState(error: error));
      }

      return;
    }

    emit(ServersExceptionState(
      error: Exception("Servers must be loaded before renaming a server."),
    ));
  }

  void _onSelectServerRequested(
    SelectServerRequested event,
    Emitter<ServersState> emit,
  ) {
    if (state case final ServersLoadedState state) {
      final trimmedServerId = event.serverId.trim();
      final selectedServer = state.servers.firstWhereOrNull(
        (server) => server.id == trimmedServerId,
      );

      emit(state.selectServer(incomingSelectedServer: selectedServer));
    }
  }
}
