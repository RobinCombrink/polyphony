import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../../../shared/models/chat_models.dart';
import '../../../shared/network/polyphony_api_client.dart';
import '../../../shared/result/result.dart';
import 'chat_browser_event.dart';
import 'chat_browser_state.dart';

class ChatBrowserBloc extends Bloc<ChatBrowserEvent, ChatBrowserState> {
  ChatBrowserBloc({required http.Client httpClient})
      : _httpClient = httpClient,
        super(const ChatBrowserInitialState()) {
    on<LoadServersRequested>(_onLoadServersRequested);
    on<ServerSelected>(_onServerSelected);
    on<ChannelSelected>(_onChannelSelected);
  }

  final http.Client _httpClient;

  Future<void> _onLoadServersRequested(
    LoadServersRequested event,
    Emitter<ChatBrowserState> emit,
  ) async {
    final trimmedToken = event.bearerToken.trim();
    final trimmedBaseUrl = event.baseUrl.trim();

    final loadingState = switch (state) {
      ChatBrowserInitialState current => trimmedToken.isEmpty
          ? current.missingToken()
          : current.startLoadingServers(
              bearerToken: trimmedToken,
              baseUrl: trimmedBaseUrl,
            ),
      ChatBrowserReadyState current => trimmedToken.isEmpty
          ? ChatBrowserFailureState(
              statusMessage: 'Auth token is required.',
              context: current.context,
            )
          : current.reloadServers(),
      ChatBrowserFailureState current => trimmedToken.isEmpty
          ? current
          : current.retryLoadingServers(
              bearerToken: trimmedToken,
              baseUrl: trimmedBaseUrl,
            ),
      ChatBrowserLoadingState current => current,
      ChatBrowserAuthenticatedState current => ChatBrowserLoadingServersState(
          statusMessage: 'Loading servers...',
          context: current.context,
        ),
    };

    if (loadingState is ChatBrowserFailureState) {
      emit(loadingState);
      return;
    }

    if (loadingState is! ChatBrowserLoadingServersState) {
      emit(const ChatBrowserFailureState(
        statusMessage: 'Unable to start loading servers from current state.',
        context: null,
      ));
      return;
    }

    emit(loadingState);

    final apiClient = PolyphonyApiClient(
      baseUrl: loadingState.context.baseUrl,
      httpClient: _httpClient,
    );

    final listServersResult = await apiClient.listServers(
        bearerToken: loadingState.context.bearerToken);

    switch (listServersResult) {
      case Ok<List<Server>>(:final value):
        emit(loadingState.finishWithServers(value));
      case Error<List<Server>>(:final error):
        emit(loadingState.fail(error));
    }
  }

  Future<void> _onServerSelected(
    ServerSelected event,
    Emitter<ChatBrowserState> emit,
  ) async {
    final loadingState = switch (state) {
      ChatBrowserReadyState current => current.selectServer(event.server),
      _ => null,
    };

    if (loadingState == null) {
      emit(const ChatBrowserFailureState(
        statusMessage: 'Select server is only valid from ready state.',
        context: null,
      ));
      return;
    }

    emit(loadingState);

    final apiClient = PolyphonyApiClient(
      baseUrl: loadingState.context.baseUrl,
      httpClient: _httpClient,
    );

    final listChannelsResult = await apiClient.listChannels(
      bearerToken: loadingState.context.bearerToken,
      serverId: event.server.id,
    );

    switch (listChannelsResult) {
      case Ok<List<Channel>>(:final value):
        emit(loadingState.finishWithChannels(value));
      case Error<List<Channel>>(:final error):
        emit(loadingState.fail(error));
    }
  }

  Future<void> _onChannelSelected(
    ChannelSelected event,
    Emitter<ChatBrowserState> emit,
  ) async {
    final loadingState = switch (state) {
      ChatBrowserReadyState current => current.selectChannel(event.channel),
      _ => null,
    };

    if (loadingState == null) {
      emit(const ChatBrowserFailureState(
        statusMessage: 'Select channel is only valid from ready state.',
        context: null,
      ));
      return;
    }

    emit(loadingState);

    final apiClient = PolyphonyApiClient(
      baseUrl: loadingState.context.baseUrl,
      httpClient: _httpClient,
    );

    final listMessagesResult = await apiClient.listMessages(
      bearerToken: loadingState.context.bearerToken,
      channelId: event.channel.id,
    );

    switch (listMessagesResult) {
      case Ok<List<Message>>(:final value):
        emit(loadingState.finishWithMessages(value));
      case Error<List<Message>>(:final error):
        emit(loadingState.fail(error));
    }
  }

  @override
  Future<void> close() {
    _httpClient.close();
    return super.close();
  }
}
