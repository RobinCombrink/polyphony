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

    final listServersResult = await _serverRepo.getMany(
      query: const GetServersQuery(),
    );

    switch (listServersResult) {
      case Ok<Iterable<Server>>(:final value):
        final servers = value.toList();
        final selectedServerId = value.any(
          (server) => server.id == previousLoadedState?.selectedServerId,
        )
            ? previousLoadedState?.selectedServerId
            : null;

        emit(ServersLoadedState(
          servers: servers,
          selectedServerId: selectedServerId,
        ));
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
          final ServersLoadedDataState loadedState =>
            ServersValidationFailedState(
              issue: ServersValidationIssue.serverNameRequired,
              servers: loadedState.servers,
              selectedServerId: loadedState.selectedServerId,
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
            emit(ServersLoadedState(
              servers: servers,
              selectedServerId: servers.any(
                (server) => server.id == createdServer.id,
              )
                  ? createdServer.id
                  : null,
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
    final loadedState = switch (state) {
      final ServersLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ServersExceptionState(
        error: Exception("Servers must be loaded before deleting a server."),
      ));
      return;
    }

    final trimmedServerId = event.serverId.trim();
    if (trimmedServerId.isEmpty ||
        !loadedState.servers.any((server) => server.id == trimmedServerId)) {
      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.serverSelectionRequired,
        servers: loadedState.servers,
        selectedServerId: loadedState.selectedServerId,
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
            final previousSelectedServerId = loadedState.selectedServerId;
            final selectedServerId = previousSelectedServerId != null &&
                    servers.any(
                      (server) => server.id == previousSelectedServerId,
                    )
                ? previousSelectedServerId
                : null;

            emit(ServersLoadedState(
              servers: servers,
              selectedServerId: selectedServerId,
            ));
          case Error<Iterable<Server>>(:final error):
            emit(ServersExceptionState(error: error));
        }
      case Error<void>(:final error):
        emit(ServersExceptionState(error: error));
    }
  }

  void _onSelectServerRequested(
    SelectServerRequested event,
    Emitter<ServersState> emit,
  ) {
    final loadedState = switch (state) {
      final ServersLoadedDataState loadedState => loadedState,
      _ => null,
    };

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
    final loadedState = switch (state) {
      final ServersLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ServersExceptionState(
        error: Exception("Servers must be loaded before adding a member."),
      ));
      return;
    }

    final trimmedServerId = event.serverId.trim();
    final trimmedUserId = event.userId.trim();

    if (trimmedServerId.isEmpty ||
        !loadedState.servers.any((server) => server.id == trimmedServerId)) {
      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.serverSelectionRequired,
        servers: loadedState.servers,
        selectedServerId: loadedState.selectedServerId,
      ));
      return;
    }

    if (trimmedUserId.isEmpty) {
      emit(ServersValidationFailedState(
        issue: ServersValidationIssue.userIdRequired,
        servers: loadedState.servers,
        selectedServerId: loadedState.selectedServerId,
      ));
      return;
    }

    emit(const ServersLoadingState());

    final addMemberResult = await _serverRepo.updateOne(
      command: AddServerMemberCommand(
        serverId: trimmedServerId,
        userId: trimmedUserId,
      ),
    );

    switch (addMemberResult) {
      case Ok<void>():
        final listServersResult = await _serverRepo.getMany(
          query: const GetServersQuery(),
        );

        switch (listServersResult) {
          case Ok<Iterable<Server>>(:final value):
            final servers = value.toList();
            emit(ServersLoadedState(
              servers: servers,
              selectedServerId: servers.any(
                (server) => server.id == trimmedServerId,
              )
                  ? trimmedServerId
                  : null,
            ));
          case Error<Iterable<Server>>(:final error):
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
