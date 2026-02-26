import "package:flutter/material.dart";

class ListSectionWidget<T> extends StatelessWidget {
  const ListSectionWidget({
    required this.title,
    required this.items,
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.isLoading,
    required this.createController,
    required this.createLabel,
    required this.createActionLabel,
    required this.onCreate,
    this.showCreateControls = true,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final List<T> items;
  final bool Function(T item) isSelected;
  final String Function(T item) label;
  final String? Function(T item)? subtitle;
  final Widget? Function(T item)? trailing;
  final void Function(T item) onTap;
  final bool isLoading;
  final TextEditingController createController;
  final String createLabel;
  final String createActionLabel;
  final VoidCallback onCreate;
  final bool showCreateControls;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          if (showCreateControls)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: createController,
                      decoration: InputDecoration(labelText: createLabel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isLoading ? null : onCreate,
                    child: Text(createActionLabel),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final itemSubtitle = subtitle?.call(item);

                return ListTile(
                  selected: isSelected(item),
                  title: Text(label(item)),
                  subtitle: itemSubtitle != null ? Text(itemSubtitle) : null,
                  trailing: trailing?.call(item),
                  onTap: isLoading ? null : () => onTap(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
