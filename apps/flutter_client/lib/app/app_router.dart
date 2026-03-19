import "package:go_router/go_router.dart";
import "package:polyphony_flutter_client/app/app_route.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/features/home/presentation/direct_messages_page_widget.dart";
import "package:polyphony_flutter_client/features/home/presentation/home_page_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/settings_page_route_widget.dart";

GoRouter createAppRouter() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        name: AppRouteId.authGate.name,
        path: AppRouteId.authGate.path,
        builder: (_, __) => const AuthenticationGateWidget(),
      ),
      ShellRoute(
        builder: (_, __, child) => AuthenticationGateWidget(
          authenticatedChild: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            name: AppRouteId.appHome.name,
            path: AppRouteId.appHome.path,
            builder: (_, __) => const HomePageWidget(),
          ),
          GoRoute(
            name: AppRouteId.directMessages.name,
            path: AppRouteId.directMessages.path,
            builder: (_, __) => const DirectMessagesPageWidget(),
          ),
          GoRoute(
            name: AppRouteId.settings.name,
            path: AppRouteId.settings.path,
            builder: (_, __) => const SettingsPageRouteWidget(),
          ),
        ],
      ),
    ],
  );
}
