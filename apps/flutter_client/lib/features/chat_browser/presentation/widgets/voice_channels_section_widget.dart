import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

SectionStatus? buildVoiceChannelsSectionStatus(VoiceSessionsState state) {
  if (state is VoiceSessionsValidationFailedState) {
    return const SectionStatus(
      message: "Select a channel first.",
      isError: true,
    );
  }

  if (state is VoiceSessionsExceptionState) {
    return SectionStatus(
      message: "Voice operation failed: ${state.error}",
      isError: true,
    );
  }

  return null;
}

class VoiceChannelsSectionWidget extends StatelessWidget {
  const VoiceChannelsSectionWidget({
    required this.participants,
    required this.channelName,
    required this.selfParticipantUserId,
    required this.isLoading,
    required this.isConnected,
    required this.isSelfMuted,
    required this.isSelfDeafened,
    required this.onLeave,
    required this.onToggleSelfMute,
    required this.onToggleSelfDeafen,
    super.key,
  });

  final List<VoiceParticipant> participants;
  final String channelName;
  final String? selfParticipantUserId;
  final bool isLoading;
  final bool isConnected;
  final bool isSelfMuted;
  final bool isSelfDeafened;
  final VoidCallback onLeave;
  final VoidCallback onToggleSelfMute;
  final VoidCallback onToggleSelfDeafen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "Voice participants · $channelName",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed:
                      isLoading || !isConnected ? null : onToggleSelfMute,
                  icon: Icon(isSelfMuted ? Icons.mic_off : Icons.mic),
                  label: Text(isSelfMuted ? "Unmute" : "Mute"),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      isLoading || !isConnected ? null : onToggleSelfDeafen,
                  icon: Icon(
                    isSelfDeafened ? Icons.headset_off : Icons.headset,
                  ),
                  label: Text(isSelfDeafened ? "Undeafen" : "Deafen"),
                ),
                FilledButton.tonal(
                  onPressed: isLoading || !isConnected ? null : onLeave,
                  child: const Text("Leave voice"),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                if (participants.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.mic_off),
                    title: Text("No participants"),
                  )
                else
                  ...participants.map(
                    (participant) {
                      final isSelfParticipant =
                          participant.userId == selfParticipantUserId;
                      final showDeafenedIcon =
                          isSelfParticipant && isSelfDeafened;

                      return ListTile(
                        leading: const Icon(Icons.account_circle),
                        title: Text(participant.displayName),
                        trailing: participant.isMuted || showDeafenedIcon
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (participant.isMuted)
                                    const Icon(Icons.mic_off),
                                  if (showDeafenedIcon)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.headset_off),
                                    ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
