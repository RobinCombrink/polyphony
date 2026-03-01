import "package:flutter/material.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

sealed class ChannelWidget extends StatelessWidget {
  const ChannelWidget({
    required this.channel,
    required this.isSelected,
    required this.showParticipantCount,
    required this.voiceParticipantCount,
    required this.isConnectedVoiceChannel,
    required this.voiceParticipants,
    required this.selfParticipantUserId,
    required this.isSelfDeafened,
    required this.onTap,
    super.key,
  });

  final Channel channel;
  final bool isSelected;
  final bool showParticipantCount;
  final int voiceParticipantCount;
  final bool isConnectedVoiceChannel;
  final List<VoiceParticipant> voiceParticipants;
  final String? selfParticipantUserId;
  final bool isSelfDeafened;
  final VoidCallback? onTap;

  factory ChannelWidget.fromChannel({
    required Channel channel,
    required bool isSelected,
    required bool showParticipantCount,
    required int voiceParticipantCount,
    required bool isConnectedVoiceChannel,
    required List<VoiceParticipant> voiceParticipants,
    required String? selfParticipantUserId,
    required bool isSelfDeafened,
    required VoidCallback? onTap,
    Key? key,
  }) {
    return switch (channel) {
      TextChannel() => TextChannelWidget(
          key: key,
          channel: channel,
          isSelected: isSelected,
          showParticipantCount: showParticipantCount,
          voiceParticipantCount: voiceParticipantCount,
          onTap: onTap,
        ),
      VoiceChannel() => VoiceChannelWidget(
          key: key,
          channel: channel,
          isSelected: isSelected,
          showParticipantCount: showParticipantCount,
          voiceParticipantCount: voiceParticipantCount,
          isConnectedVoiceChannel: isConnectedVoiceChannel,
          voiceParticipants: voiceParticipants,
          selfParticipantUserId: selfParticipantUserId,
          isSelfDeafened: isSelfDeafened,
          onTap: onTap,
        ),
    };
  }
}

final class TextChannelWidget extends ChannelWidget {
  const TextChannelWidget({
    required TextChannel channel,
    required super.isSelected,
    required super.showParticipantCount,
    required super.voiceParticipantCount,
    required super.onTap,
    super.key,
  }) : super(
          channel: channel,
          isConnectedVoiceChannel: false,
          voiceParticipants: const <VoiceParticipant>[],
          selfParticipantUserId: null,
          isSelfDeafened: false,
        );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isSelected,
      leading: const Icon(Icons.tag, size: 18),
      title: Text(channel.name),
      trailing: showParticipantCount
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.mic, size: 16),
                const SizedBox(width: 4),
                Text(voiceParticipantCount.toString()),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}

final class VoiceChannelWidget extends ChannelWidget {
  const VoiceChannelWidget({
    required VoiceChannel channel,
    required super.isSelected,
    required super.showParticipantCount,
    required super.voiceParticipantCount,
    required super.isConnectedVoiceChannel,
    required super.voiceParticipants,
    required super.selfParticipantUserId,
    required super.isSelfDeafened,
    required super.onTap,
    super.key,
  }) : super(channel: channel);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isSelected,
      leading: const Icon(Icons.volume_up, size: 18),
      title: Text(channel.name),
      subtitle: voiceParticipants.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: voiceParticipants.map((participant) {
                  final isSelfParticipant =
                      participant.userId == selfParticipantUserId;
                  final showSelfDeafened = isSelfParticipant && isSelfDeafened;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.account_circle, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            participant.displayName,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (participant.isMuted)
                          const Icon(
                            Icons.mic_off,
                            size: 14,
                          ),
                        if (showSelfDeafened)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.headset_off,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          : null,
      trailing: isConnectedVoiceChannel || showParticipantCount
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (isConnectedVoiceChannel)
                  const Icon(Icons.headset, size: 16),
                if (isConnectedVoiceChannel && showParticipantCount)
                  const SizedBox(width: 4),
                if (showParticipantCount)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.headset, size: 16),
                      const SizedBox(width: 4),
                      Text(voiceParticipantCount.toString()),
                    ],
                  ),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}
