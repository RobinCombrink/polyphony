import "dart:async";

import "package:flutter/material.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";

class MessageSearchDialogWidget extends StatefulWidget {
  const MessageSearchDialogWidget({
    required this.messageService,
    required this.channelId,
    super.key,
  });

  final MessageService messageService;
  final ChannelId channelId;

  @override
  State<MessageSearchDialogWidget> createState() =>
      _MessageSearchDialogWidgetState();
}

class _MessageSearchDialogWidgetState extends State<MessageSearchDialogWidget> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _results = const <Message>[];
  var _isLoading = false;
  String? _errorMessage;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_performSearch(query));
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = const <Message>[];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.messageService.searchMessages(
      channelId: widget.channelId.value,
      query: query.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      switch (result) {
        case Ok<List<ApiMessage>>(:final value):
          _results =
              value.map((apiMessage) => apiMessage.toDomainModel()).toList();
          _errorMessage = null;
        case Error<List<ApiMessage>>(:final error):
          _results = const <Message>[];
          _errorMessage = "Search failed: $error";
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Search messages...",
          ),
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: 12),
        Flexible(
          child: _buildResultsBody(),
        ),
      ],
    );
  }

  Widget _buildResultsBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_controller.text.trim().isEmpty) {
      return const Center(
        child: Text(
          "Enter a search term to find messages.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              "No messages found",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = _results[index];
        return ListTile(
          leading: const Icon(Icons.message_outlined, size: 20),
          title: Text(
            message.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
