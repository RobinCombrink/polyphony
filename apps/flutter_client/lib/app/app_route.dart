enum AppRouteId {
  authGate(name: "auth_gate", path: "/"),
  appHome(name: "app_home", path: "/app"),
  directMessages(name: "direct_messages", path: "/app/dms"),
  settings(name: "settings", path: "/app/settings");

  final String name;
  final String path;

  const AppRouteId({required this.name, required this.path});
}
