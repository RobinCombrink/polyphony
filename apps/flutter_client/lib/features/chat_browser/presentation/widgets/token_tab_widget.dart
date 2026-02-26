import "package:flutter/material.dart";
import "package:flutter/services.dart";

class TokenTabWidget extends StatelessWidget {
  const TokenTabWidget({required this.bearerToken, super.key});

  final String bearerToken;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton(
            onPressed: bearerToken.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: bearerToken));

                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Token copied")),
                    );
                  },
            child: const Text("Copy Token"),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(bearerToken),
            ),
          ),
        ],
      ),
    );
  }
}
