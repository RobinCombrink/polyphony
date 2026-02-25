part of "channels_bloc.dart";

sealed class ChannelsEvent {
  const ChannelsEvent();
}

final class ResetChannelsRequested extends ChannelsEvent {
  const ResetChannelsRequested();
}

final class LoadChannelsRequested extends ChannelsEvent {
  const LoadChannelsRequested({
    required this.baseUrl,
    required this.serverId,
  });

  final String baseUrl;
  final String serverId;
}

final class CreateChannelRequested extends ChannelsEvent {
  const CreateChannelRequested({
    required this.baseUrl,
    required this.serverId,
    required this.channelName,
  });

  final String baseUrl;
  final String serverId;
  final String channelName;
}
