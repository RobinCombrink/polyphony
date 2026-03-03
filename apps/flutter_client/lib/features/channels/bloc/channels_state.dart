part of "channels_bloc.dart";

enum ChannelsValidationIssue {
  serverSelectionRequired,
  channelNameRequired,
  channelSelectionRequired,
}

enum ChannelSelectionMode {
  text,
  voice,
}

sealed class ChannelsState {
  const ChannelsState();
}

final class ChannelsInitialState extends ChannelsState {
  const ChannelsInitialState();
}

final class ChannelsLoadingState extends ChannelsState {
  const ChannelsLoadingState();
}

sealed class ChannelsLoadedDataState extends ChannelsState {
  const ChannelsLoadedDataState({
    required this.textChannels,
    required this.voiceChannels,
    required this.serverId,
    required this.selectedTextChannelId,
    required this.selectedVoiceChannelId,
    required this.selectionMode,
  });

  final List<TextChannel> textChannels;
  final List<VoiceChannel> voiceChannels;
  final String serverId;
  final String? selectedTextChannelId;
  final String? selectedVoiceChannelId;
  final ChannelSelectionMode selectionMode;
}

final class ChannelsLoadedState extends ChannelsLoadedDataState {
  const ChannelsLoadedState({
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
    required super.selectedTextChannelId,
    required super.selectedVoiceChannelId,
    required super.selectionMode,
  });
}

final class ChannelsValidationFailedState extends ChannelsLoadedDataState {
  const ChannelsValidationFailedState({
    required this.issue,
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
    required super.selectedTextChannelId,
    required super.selectedVoiceChannelId,
    required super.selectionMode,
  });

  final ChannelsValidationIssue issue;
}

final class ChannelsExceptionState extends ChannelsState {
  const ChannelsExceptionState({required this.error});

  final Exception error;
}
