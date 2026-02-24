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

final class CreateServerRequested extends ChatBrowserEvent {
  const CreateServerRequested(this.serverName);

  final String serverName;
}

final class CreateChannelRequested extends ChatBrowserEvent {
  const CreateChannelRequested(this.channelName);

  final String channelName;
}

final class CreateMessageRequested extends ChatBrowserEvent {
  const CreateMessageRequested(this.messageContent);

  final String messageContent;
}
