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
    required this.voiceSessions,
    required this.isLoading,
    required this.onJoin,
    required this.onLeave,
    required this.onRefresh,
    super.key,
  });

  final List<VoiceSession> voiceSessions;
  final bool isLoading;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Voice",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: isLoading ? null : onJoin,
                  child: const Text("Join"),
                ),
                FilledButton.tonal(
                  onPressed: isLoading ? null : onLeave,
                  child: const Text("Leave"),
                ),
                OutlinedButton(
                  onPressed: isLoading ? null : onRefresh,
                  child: const Text("Refresh"),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: voiceSessions.length,
              itemBuilder: (context, index) {
                final voiceSession = voiceSessions[index];

                return ListTile(
                  leading: const Icon(Icons.mic),
                  title: Text(voiceSession.participantSubject),
                  subtitle: Text("Channel ${voiceSession.channelId}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
