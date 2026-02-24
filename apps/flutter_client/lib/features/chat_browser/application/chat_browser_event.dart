import '../../../shared/models/chat_models.dart';

sealed class ChatBrowserEvent {
  const ChatBrowserEvent();
}

final class LoadServersRequested extends ChatBrowserEvent {
  const LoadServersRequested(
      {required this.bearerToken, required this.baseUrl});

  final String bearerToken;
  final String baseUrl;
}

final class ServerSelected extends ChatBrowserEvent {
  const ServerSelected(this.server);

  final Server server;
}

final class ChannelSelected extends ChatBrowserEvent {
  const ChannelSelected(this.channel);

  final Channel channel;
}
