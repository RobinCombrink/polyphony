part of "channels_bloc.dart";

sealed class ChannelsEvent {
  const ChannelsEvent();
}

final class ResetChannelsRequested extends ChannelsEvent {
  const ResetChannelsRequested();
}

final class LoadChannelsRequested extends ChannelsEvent {
  const LoadChannelsRequested({
    required this.serverId,
  });

  final String serverId;
}

final class CreateChannelRequested extends ChannelsEvent {
  const CreateChannelRequested({
    required this.serverId,
    required this.channelName,
  });

  final String serverId;
  final String channelName;
}

final class DeleteChannelRequested extends ChannelsEvent {
  const DeleteChannelRequested({
    required this.channelId,
  });

  final String channelId;
}

final class SelectTextChannelRequested extends ChannelsEvent {
  const SelectTextChannelRequested({required this.channelId});

  final String channelId;
}

final class SelectVoiceChannelRequested extends ChannelsEvent {
  const SelectVoiceChannelRequested({required this.channelId});

  final String channelId;
}
