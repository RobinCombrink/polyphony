part of "channels_bloc.dart";

enum ChannelsValidationIssue {
  serverSelectionRequired,
  channelNameRequired,
  channelSelectionRequired,
}

sealed class ChannelsState {
  const ChannelsState();

  ChannelsLoadedState loadChannels({
    required ServerId serverId,
    required List<TextChannel> textChannels,
    required List<VoiceChannel> voiceChannels,
  }) {
    return switch (this) {
      ChannelsInitialState() || ChannelsLoadingState() => NoChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
        ),
      final ChannelsLoadedDataState loadedState => loadedState.loadChannels(
          serverId: serverId,
          textChannels: textChannels,
          voiceChannels: voiceChannels,
        ),
      ChannelsExceptionState() => NoChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
        ),
    };
  }
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
  });

  final List<TextChannel> textChannels;
  final List<VoiceChannel> voiceChannels;
  final ServerId serverId;

  @override
  ChannelsLoadedState loadChannels({
    required ServerId serverId,
    required List<TextChannel> textChannels,
    required List<VoiceChannel> voiceChannels,
  }) {
    final selectedState = switch (this) {
      NoChannelSelected() ||
      NoChannelSelectedValidationFailedState() =>
        NoChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
        ),
      TextChannelSelected(:final selectedTextChannel) ||
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      )
          when textChannels.any(
            (channel) => channel.id == selectedTextChannel.id,
          ) =>
        TextChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
          selectedTextChannel: textChannels.firstWhere(
            (channel) => channel.id == selectedTextChannel.id,
          ),
        ),
      VoiceChannelSelected(:final selectedVoiceChannel) ||
      VoiceChannelSelectedValidationFailedState(
        :final selectedVoiceChannel,
      )
          when voiceChannels.any(
            (channel) => channel.id == selectedVoiceChannel.id,
          ) =>
        VoiceChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
          selectedVoiceChannel: voiceChannels.firstWhere(
            (channel) => channel.id == selectedVoiceChannel.id,
          ),
        ),
      _ => NoChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
        ),
    };

    return switch (this) {
      final ChannelsValidationFailedState validationState =>
        selectedState.withValidationIssue(issue: validationState.issue),
      _ => selectedState,
    };
  }
}

sealed class ChannelsLoadedState extends ChannelsLoadedDataState {
  const ChannelsLoadedState({
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
  });

  ChannelsLoadedState selectTextChannel({
    required TextChannel? incomingSelectedTextChannel,
  }) {
    if (incomingSelectedTextChannel == null) {
      return NoChannelSelected(
        textChannels: textChannels,
        voiceChannels: voiceChannels,
        serverId: serverId,
      );
    }

    final selectedTextChannel = textChannels.firstWhere(
      (channel) => channel.id == incomingSelectedTextChannel.id,
      orElse: () => incomingSelectedTextChannel,
    );

    if (!textChannels.any((channel) => channel.id == selectedTextChannel.id)) {
      return NoChannelSelected(
        textChannels: textChannels,
        voiceChannels: voiceChannels,
        serverId: serverId,
      );
    }

    return TextChannelSelected(
      textChannels: textChannels,
      voiceChannels: voiceChannels,
      serverId: serverId,
      selectedTextChannel: selectedTextChannel,
    );
  }

  ChannelsLoadedState selectVoiceChannel({
    required VoiceChannel? incomingSelectedVoiceChannel,
  }) {
    if (incomingSelectedVoiceChannel == null) {
      return NoChannelSelected(
        textChannels: textChannels,
        voiceChannels: voiceChannels,
        serverId: serverId,
      );
    }

    final selectedVoiceChannel = voiceChannels.firstWhere(
      (channel) => channel.id == incomingSelectedVoiceChannel.id,
      orElse: () => incomingSelectedVoiceChannel,
    );

    if (!voiceChannels
        .any((channel) => channel.id == selectedVoiceChannel.id)) {
      return NoChannelSelected(
        textChannels: textChannels,
        voiceChannels: voiceChannels,
        serverId: serverId,
      );
    }

    return VoiceChannelSelected(
      textChannels: textChannels,
      voiceChannels: voiceChannels,
      serverId: serverId,
      selectedVoiceChannel: selectedVoiceChannel,
    );
  }

  ChannelsLoadedState deleteChannel({
    required ChannelId channelId,
    required List<TextChannel> nextTextChannels,
    required List<VoiceChannel> nextVoiceChannels,
  }) {
    final nextUnvalidatedState = switch (this) {
      NoChannelSelected() ||
      NoChannelSelectedValidationFailedState() =>
        NoChannelSelected(
          textChannels: nextTextChannels,
          voiceChannels: nextVoiceChannels,
          serverId: serverId,
        ),
      TextChannelSelected(:final selectedTextChannel) ||
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      )
          when selectedTextChannel.id == channelId =>
        NoChannelSelected(
          textChannels: nextTextChannels,
          voiceChannels: nextVoiceChannels,
          serverId: serverId,
        ),
      TextChannelSelected(:final selectedTextChannel) ||
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      )
          when nextTextChannels
              .any((channel) => channel.id == selectedTextChannel.id) =>
        TextChannelSelected(
          textChannels: nextTextChannels,
          voiceChannels: nextVoiceChannels,
          serverId: serverId,
          selectedTextChannel: nextTextChannels.firstWhere(
            (channel) => channel.id == selectedTextChannel.id,
          ),
        ),
      VoiceChannelSelected(:final selectedVoiceChannel) ||
      VoiceChannelSelectedValidationFailedState(
        :final selectedVoiceChannel,
      )
          when selectedVoiceChannel.id == channelId =>
        NoChannelSelected(
          textChannels: nextTextChannels,
          voiceChannels: nextVoiceChannels,
          serverId: serverId,
        ),
      VoiceChannelSelected(:final selectedVoiceChannel) ||
      VoiceChannelSelectedValidationFailedState(
        :final selectedVoiceChannel,
      )
          when nextVoiceChannels
              .any((channel) => channel.id == selectedVoiceChannel.id) =>
        VoiceChannelSelected(
          textChannels: nextTextChannels,
          voiceChannels: nextVoiceChannels,
          serverId: serverId,
          selectedVoiceChannel: nextVoiceChannels.firstWhere(
            (channel) => channel.id == selectedVoiceChannel.id,
          ),
        ),
      _ => NoChannelSelected(
          textChannels: nextTextChannels,
          voiceChannels: nextVoiceChannels,
          serverId: serverId,
        ),
    };

    return switch (this) {
      final ChannelsValidationFailedState validationState =>
        nextUnvalidatedState.withValidationIssue(issue: validationState.issue),
      _ => nextUnvalidatedState,
    };
  }

  ChannelsValidationFailedState withValidationIssue({
    required ChannelsValidationIssue issue,
  }) {
    return switch (this) {
      NoChannelSelected() => NoChannelSelectedValidationFailedState(
          issue: issue,
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
        ),
      TextChannelSelected(:final selectedTextChannel) =>
        TextChannelSelectedValidationFailedState(
          issue: issue,
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
          selectedTextChannel: selectedTextChannel,
        ),
      VoiceChannelSelected(:final selectedVoiceChannel) =>
        VoiceChannelSelectedValidationFailedState(
          issue: issue,
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
          selectedVoiceChannel: selectedVoiceChannel,
        ),
      final ChannelsValidationFailedState validationState => validationState,
    };
  }
}

final class NoChannelSelected extends ChannelsLoadedState {
  const NoChannelSelected({
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
  });
}

final class TextChannelSelected extends ChannelsLoadedState {
  const TextChannelSelected({
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
    required this.selectedTextChannel,
  });

  final TextChannel selectedTextChannel;
}

final class VoiceChannelSelected extends ChannelsLoadedState {
  const VoiceChannelSelected({
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
    required this.selectedVoiceChannel,
  });

  final VoiceChannel selectedVoiceChannel;
}

sealed class ChannelsValidationFailedState extends ChannelsLoadedState {
  const ChannelsValidationFailedState({
    required this.issue,
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
  });

  final ChannelsValidationIssue issue;
}

final class NoChannelSelectedValidationFailedState
    extends ChannelsValidationFailedState {
  const NoChannelSelectedValidationFailedState({
    required super.issue,
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
  });
}

final class TextChannelSelectedValidationFailedState
    extends ChannelsValidationFailedState {
  const TextChannelSelectedValidationFailedState({
    required super.issue,
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
    required this.selectedTextChannel,
  });

  final TextChannel selectedTextChannel;
}

final class VoiceChannelSelectedValidationFailedState
    extends ChannelsValidationFailedState {
  const VoiceChannelSelectedValidationFailedState({
    required super.issue,
    required super.textChannels,
    required super.voiceChannels,
    required super.serverId,
    required this.selectedVoiceChannel,
  });

  final VoiceChannel selectedVoiceChannel;
}

final class ChannelsExceptionState extends ChannelsState {
  const ChannelsExceptionState({required this.error});

  final Exception error;
}
