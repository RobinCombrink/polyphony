import '../../../shared/models/chat_models.dart';

class ChatBrowserContext {
  const ChatBrowserContext({
    required this.bearerToken,
    required this.baseUrl,
    required this.servers,
    required this.channels,
    required this.messages,
    required this.selectedServer,
    required this.selectedChannel,
  });

  final String bearerToken;
  final String baseUrl;
  final List<Server> servers;
  final List<Channel> channels;
  final List<Message> messages;
  final Server? selectedServer;
  final Channel? selectedChannel;

  factory ChatBrowserContext.withCredentials({
    required String bearerToken,
    required String baseUrl,
  }) {
    return ChatBrowserContext(
      bearerToken: bearerToken,
      baseUrl: baseUrl,
      servers: const <Server>[],
      channels: const <Channel>[],
      messages: const <Message>[],
      selectedServer: null,
      selectedChannel: null,
    );
  }

  ChatBrowserContext withServers(List<Server> nextServers) {
    return ChatBrowserContext(
      bearerToken: bearerToken,
      baseUrl: baseUrl,
      servers: nextServers,
      channels: const <Channel>[],
      messages: const <Message>[],
      selectedServer: null,
      selectedChannel: null,
    );
  }

  ChatBrowserContext selectingServer(Server server) {
    return ChatBrowserContext(
      bearerToken: bearerToken,
      baseUrl: baseUrl,
      servers: servers,
      channels: const <Channel>[],
      messages: const <Message>[],
      selectedServer: server,
      selectedChannel: null,
    );
  }

  ChatBrowserContext withChannels(List<Channel> nextChannels) {
    return ChatBrowserContext(
      bearerToken: bearerToken,
      baseUrl: baseUrl,
      servers: servers,
      channels: nextChannels,
      messages: const <Message>[],
      selectedServer: selectedServer,
      selectedChannel: null,
    );
  }

  ChatBrowserContext selectingChannel(Channel channel) {
    return ChatBrowserContext(
      bearerToken: bearerToken,
      baseUrl: baseUrl,
      servers: servers,
      channels: channels,
      messages: const <Message>[],
      selectedServer: selectedServer,
      selectedChannel: channel,
    );
  }

  ChatBrowserContext withMessages(List<Message> nextMessages) {
    return ChatBrowserContext(
      bearerToken: bearerToken,
      baseUrl: baseUrl,
      servers: servers,
      channels: channels,
      messages: nextMessages,
      selectedServer: selectedServer,
      selectedChannel: selectedChannel,
    );
  }
}
