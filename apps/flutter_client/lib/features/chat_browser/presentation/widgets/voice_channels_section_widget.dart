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
    required this.isLoading,
    required this.onLeave,
    super.key,
  });

  final List<VoiceParticipant> participants;
  final String channelName;
  final bool isLoading;
  final VoidCallback onLeave;

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
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: isLoading ? null : onLeave,
                child: const Text("Leave voice"),
              ),
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
                    (participant) => ListTile(
                      leading: const Icon(Icons.mic),
                      title: Text(participant.displayName),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
