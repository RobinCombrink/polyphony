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

  final ServerId serverId;
}

final class CreateChannelRequested extends ChannelsEvent {
  const CreateChannelRequested({
    required this.serverId,
    required this.channelName,
    required this.channelType,
  });

  final ServerId serverId;
  final String channelName;
  final ChannelType channelType;
}

final class DeleteChannelRequested extends ChannelsEvent {
  const DeleteChannelRequested({
    required this.channelId,
  });

  final ChannelId channelId;
}

final class UpdateChannelNameRequested extends ChannelsEvent {
  const UpdateChannelNameRequested({
    required this.channelId,
    required this.name,
  });

  final ChannelId channelId;
  final String name;
}

final class SelectTextChannelRequested extends ChannelsEvent {
  const SelectTextChannelRequested({required this.channelId});

  final ChannelId channelId;
}

final class SelectVoiceChannelRequested extends ChannelsEvent {
  const SelectVoiceChannelRequested({required this.channelId});

  final ChannelId channelId;
}
