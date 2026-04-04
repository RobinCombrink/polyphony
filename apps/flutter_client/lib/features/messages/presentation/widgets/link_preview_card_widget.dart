import "package:flutter/material.dart";

class LinkPreviewCardWidget extends StatelessWidget {
  const LinkPreviewCardWidget({
    required this.title,
    this.description,
    this.url,
    super.key,
  });

  final String title;
  final String? description;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (url != null) ...[
            const SizedBox(height: 4),
            Text(
              url!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
