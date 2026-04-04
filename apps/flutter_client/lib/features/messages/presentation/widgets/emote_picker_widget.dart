import "dart:async";

import "package:flutter/material.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";
import "package:provider/provider.dart";

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
  var _emotes = const <Emote>[];
  var _searchQuery = "";
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEmotes());
  }

  Future<void> _loadEmotes() async {
    final service = context.read<EmoteService>();
    final result = await service.listEmotes();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      if (result case Ok<List<Emote>>(:final value)) {
        _emotes = value;
      }
    });
  }

  List<Emote> get _filteredEmotes {
    if (_searchQuery.isEmpty) {
      return _emotes;
    }
    final query = _searchQuery.toLowerCase();
    return _emotes
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildEmoteGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmoteGrid() {
    final emotes = _filteredEmotes;
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
