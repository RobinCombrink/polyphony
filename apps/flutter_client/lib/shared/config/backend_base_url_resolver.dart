import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

String normalizeBackendBaseUrl(String value) {
  final trimmed = value.trim();

  if (trimmed.endsWith("/")) {
    return trimmed.substring(0, trimmed.length - 1);
  }

  return trimmed;
}

Future<String> resolveBackendBaseUrl({
  required PreferencesStore preferencesStore,
  String? fallback,
}) async {
  final override = await preferencesStore.readBackendBaseUrlOverride();
  final fallbackBaseUrl = fallback ?? PolyphonyConfig.backendBaseUrl;

  if (override == null || override.trim().isEmpty) {
    return normalizeBackendBaseUrl(fallbackBaseUrl);
  }

  return normalizeBackendBaseUrl(override);
}
