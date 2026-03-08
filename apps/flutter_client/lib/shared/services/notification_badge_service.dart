import "package:app_badge_plus/app_badge_plus.dart";
import "package:flutter/foundation.dart";

abstract interface class NotificationBadgeService {
  Future<void> syncUnreadCount({required int totalUnreadCount});
}

final class NoOpNotificationBadgeService implements NotificationBadgeService {
  const NoOpNotificationBadgeService();

  @override
  Future<void> syncUnreadCount({required int totalUnreadCount}) async {
    return;
  }
}

final class FlutterAppIconNotificationBadgeService
    implements NotificationBadgeService {
  const FlutterAppIconNotificationBadgeService();

  @override
  Future<void> syncUnreadCount({required int totalUnreadCount}) async {
    if (kIsWeb) {
      return;
    }

    final normalizedUnreadCount = totalUnreadCount < 0 ? 0 : totalUnreadCount;

    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (!isSupported) {
        return;
      }

      if (normalizedUnreadCount == 0) {
        await AppBadgePlus.updateBadge(0);
        return;
      }

      await AppBadgePlus.updateBadge(normalizedUnreadCount);
    } on Exception {
      return;
    }
  }
}
