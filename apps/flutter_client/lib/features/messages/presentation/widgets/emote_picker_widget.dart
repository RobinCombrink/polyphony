import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/emote_catalog_bloc.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";

class EmotePickerWidget extends StatefulWidget {
  const EmotePickerWidget({
    required this.onEmoteSelected,
    super.key,
  });

  final void Function(Emote emote) onEmoteSelected;

  @override
  State<EmotePickerWidget> createState() => _EmotePickerWidgetState();
}

class _EmotePickerWidgetState extends State<EmotePickerWidget> {
  var _searchQuery = "";

  List<Emote> _filterEmotes(List<Emote> emotes) {
    if (_searchQuery.isEmpty) {
      return emotes;
    }
    final query = _searchQuery.toLowerCase();
    return emotes
        .where((e) => e.shortcode.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 350,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search emotes...",
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: BlocBuilder<EmoteCatalogBloc, EmoteCatalogState>(
              builder: (context, state) => switch (state) {
                EmoteCatalogInitialState() ||
                EmoteCatalogLoadingState() =>
                  const Center(child: CircularProgressIndicator()),
                EmoteCatalogLoadedState(:final emotes) =>
                  _buildEmoteGrid(_filterEmotes(emotes)),
                EmoteCatalogExceptionState() =>
                  const Center(child: Text("Failed to load emotes")),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmoteGrid(List<Emote> emotes) {
    if (emotes.isEmpty) {
      return const Center(child: Text("No emotes found"));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emotes.length,
      itemBuilder: (context, index) {
        final emote = emotes[index];
        return Tooltip(
          message: emote.shortcode,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onEmoteSelected(emote),
            child: Center(
              child: Text(
                emote.emojiChar,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}
