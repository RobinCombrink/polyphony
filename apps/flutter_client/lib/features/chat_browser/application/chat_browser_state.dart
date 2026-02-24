import '../../../shared/models/chat_models.dart';
import '../domain/chat_browser_context.dart';

sealed class ChatBrowserState {
  const ChatBrowserState({required this.statusMessage});

  final String statusMessage;

  bool get isLoading => this is ChatBrowserLoadingState;

  List<Server> get servers => switch (this) {
        ChatBrowserAuthenticatedState(:final context) => context.servers,
        _ => const <Server>[],
      };

  List<Channel> get channels => switch (this) {
        ChatBrowserAuthenticatedState(:final context) => context.channels,
        _ => const <Channel>[],
      };

  List<Message> get messages => switch (this) {
        ChatBrowserAuthenticatedState(:final context) => context.messages,
        _ => const <Message>[],
      };

  Server? get selectedServer => switch (this) {
        ChatBrowserAuthenticatedState(:final context) => context.selectedServer,
        _ => null,
      };

  Channel? get selectedChannel => switch (this) {
        ChatBrowserAuthenticatedState(:final context) =>
          context.selectedChannel,
        _ => null,
      };
}

final class ChatBrowserInitialState extends ChatBrowserState {
  const ChatBrowserInitialState()
      : super(
            statusMessage: 'Enter Auth0 access token and click Load Servers.');

  ChatBrowserLoadingServersState startLoadingServers({
    required String bearerToken,
    required String baseUrl,
  }) {
    return ChatBrowserLoadingServersState(
      context: ChatBrowserContext.withCredentials(
        bearerToken: bearerToken,
        baseUrl: baseUrl,
      ),
      statusMessage: 'Loading servers...',
    );
  }

  ChatBrowserFailureState missingToken() {
    return const ChatBrowserFailureState(
      statusMessage: 'Auth token is required.',
      context: null,
    );
  }
}

sealed class ChatBrowserAuthenticatedState extends ChatBrowserState {
  const ChatBrowserAuthenticatedState({
    required super.statusMessage,
    required this.context,
  });

  final ChatBrowserContext context;
}

sealed class ChatBrowserLoadingState extends ChatBrowserAuthenticatedState {
  const ChatBrowserLoadingState({
    required super.statusMessage,
    required super.context,
  });
}

final class ChatBrowserLoadingServersState extends ChatBrowserLoadingState {
  const ChatBrowserLoadingServersState({
    required super.statusMessage,
    required super.context,
  });

  ChatBrowserReadyState finishWithServers(List<Server> servers) {
    final nextContext = context.withServers(servers);
    final message = servers.isEmpty
        ? 'No servers found for this user.'
        : 'Loaded ${servers.length} server(s).';
    return ChatBrowserReadyState(statusMessage: message, context: nextContext);
  }

  ChatBrowserFailureState fail(Exception error) {
    return ChatBrowserFailureState(
      statusMessage: 'Failed to load servers: $error',
      context: context,
    );
  }
}

final class ChatBrowserLoadingChannelsState extends ChatBrowserLoadingState {
  const ChatBrowserLoadingChannelsState({
    required super.statusMessage,
    required super.context,
  });

  ChatBrowserReadyState finishWithChannels(List<Channel> channels) {
    final nextContext = context.withChannels(channels);
    final selectedServerName = context.selectedServer?.name ?? 'server';
    final message = channels.isEmpty
        ? 'No channels found in $selectedServerName.'
        : 'Loaded ${channels.length} channel(s).';
    return ChatBrowserReadyState(statusMessage: message, context: nextContext);
  }

  ChatBrowserFailureState fail(Exception error) {
    return ChatBrowserFailureState(
      statusMessage: 'Failed to load channels: $error',
      context: context,
    );
  }
}

final class ChatBrowserLoadingMessagesState extends ChatBrowserLoadingState {
  const ChatBrowserLoadingMessagesState({
    required super.statusMessage,
    required super.context,
  });

  ChatBrowserReadyState finishWithMessages(List<Message> messages) {
    final nextContext = context.withMessages(messages);
    final selectedChannelName = context.selectedChannel?.name ?? 'channel';
    final message = messages.isEmpty
        ? 'No messages found in $selectedChannelName.'
        : 'Loaded ${messages.length} message(s).';
    return ChatBrowserReadyState(statusMessage: message, context: nextContext);
  }

  ChatBrowserFailureState fail(Exception error) {
    return ChatBrowserFailureState(
      statusMessage: 'Failed to load messages: $error',
      context: context,
    );
  }
}

final class ChatBrowserReadyState extends ChatBrowserAuthenticatedState {
  const ChatBrowserReadyState({
    required super.statusMessage,
    required super.context,
  });

  ChatBrowserLoadingServersState reloadServers() {
    return ChatBrowserLoadingServersState(
      statusMessage: 'Loading servers...',
      context: ChatBrowserContext.withCredentials(
        bearerToken: context.bearerToken,
        baseUrl: context.baseUrl,
      ),
    );
  }

  ChatBrowserLoadingChannelsState selectServer(Server server) {
    return ChatBrowserLoadingChannelsState(
      statusMessage: 'Loading channels for ${server.name}...',
      context: context.selectingServer(server),
    );
  }

  ChatBrowserLoadingMessagesState selectChannel(Channel channel) {
    return ChatBrowserLoadingMessagesState(
      statusMessage: 'Loading messages for ${channel.name}...',
      context: context.selectingChannel(channel),
    );
  }

  ChatBrowserLoadingServersState createServer() {
    return ChatBrowserLoadingServersState(
      statusMessage: 'Creating server...',
      context: context,
    );
  }

  ChatBrowserLoadingChannelsState createChannel() {
    return ChatBrowserLoadingChannelsState(
      statusMessage: 'Creating channel...',
      context: context,
    );
  }

  ChatBrowserLoadingMessagesState createMessage() {
    return ChatBrowserLoadingMessagesState(
      statusMessage: 'Sending message...',
      context: context,
    );
  }
}

final class ChatBrowserFailureState extends ChatBrowserState {
  const ChatBrowserFailureState(
      {required super.statusMessage, required this.context});

  final ChatBrowserContext? context;

  ChatBrowserLoadingServersState retryLoadingServers({
    required String bearerToken,
    required String baseUrl,
  }) {
    return ChatBrowserLoadingServersState(
      statusMessage: 'Loading servers...',
      context: ChatBrowserContext.withCredentials(
        bearerToken: bearerToken,
        baseUrl: baseUrl,
      ),
    );
  }
}
