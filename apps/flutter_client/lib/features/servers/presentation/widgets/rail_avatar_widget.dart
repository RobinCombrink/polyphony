import "package:flutter/material.dart";

class RailBadgeWidget extends StatelessWidget {
  const RailBadgeWidget({
    required this.count,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final semanticCount = switch (count) {
      < 0 => 0,
      > 99 => 99,
      _ => count,
    };

    return Positioned(
      top: -2,
      right: -2,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          semanticCount > 99 ? "99+" : "$semanticCount",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onError,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class RailAvatarWidget extends StatelessWidget {
  const RailAvatarWidget({
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.child,
    this.tooltip,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.unreadCount = 0,
    super.key,
  });

  final bool isSelected;
  final bool isHovered;
  final VoidCallback? onTap;
  final Widget child;
  final String? tooltip;
  final GestureLongPressCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = switch ((isSelected, isHovered)) {
      (true, _) => colorScheme.primary,
      (false, true) => colorScheme.primary.withAlpha(170),
      _ => Colors.transparent,
    };
    final backgroundColor = switch ((isSelected, isHovered)) {
      (true, _) => colorScheme.primaryContainer,
      (false, true) => colorScheme.surfaceContainerHighest,
      _ => null,
    };
    final foregroundColor = switch ((isSelected, isHovered)) {
      (true, _) => colorScheme.onPrimaryContainer,
      (false, true) => colorScheme.onSurface,
      _ => null,
    };

    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        child: child,
      ),
    );

    final body = unreadCount > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              avatar,
              RailBadgeWidget(count: unreadCount),
            ],
          )
        : avatar;

    final interactive = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: body,
    );

    if (tooltip == null) {
      return interactive;
    }

    return Tooltip(
      message: tooltip,
      child: interactive,
    );
  }
}
