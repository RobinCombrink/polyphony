part of "channels_bloc.dart";

enum ChannelsValidationIssue {
  serverSelectionRequired,
  channelNameRequired,
}

sealed class ChannelsState {
  const ChannelsState({required this.channels, required this.serverId});

  final List<Channel> channels;
  final String? serverId;

  bool get isLoading => this is ChannelsLoadingState;
}

final class ChannelsInitialState extends ChannelsState {
  const ChannelsInitialState()
      : super(channels: const <Channel>[], serverId: null);
}

final class ChannelsLoadingState extends ChannelsState {
  const ChannelsLoadingState({
    required super.channels,
    required super.serverId,
  });
}

final class ChannelsLoadedState extends ChannelsState {
  const ChannelsLoadedState({
    required super.channels,
    required super.serverId,
  });
}

final class ChannelsValidationFailedState extends ChannelsState {
  const ChannelsValidationFailedState({
    required this.issue,
    required super.channels,
    required super.serverId,
  });

  final ChannelsValidationIssue issue;
}

final class ChannelsExceptionState extends ChannelsState {
  const ChannelsExceptionState({
    required this.error,
    required super.channels,
    required super.serverId,
  });

  final Exception error;
}
