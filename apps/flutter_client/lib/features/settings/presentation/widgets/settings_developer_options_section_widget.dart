import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_developer_profile_bloc.dart";
import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class SettingsDeveloperOptionsSectionWidget extends StatefulWidget {
  const SettingsDeveloperOptionsSectionWidget({
    required this.bearerToken,
    super.key,
  });

  final String bearerToken;

  @override
  State<SettingsDeveloperOptionsSectionWidget> createState() =>
      _SettingsDeveloperOptionsSectionWidgetState();
}

class _SettingsDeveloperOptionsSectionWidgetState
    extends State<SettingsDeveloperOptionsSectionWidget> {
  late final TextEditingController _backendBaseUrlController;
  String _effectiveBackendBaseUrl = PolyphonyConfig.backendBaseUrl;
  var _isSavingBackendBaseUrl = false;

  @override
  void initState() {
    super.initState();
    _backendBaseUrlController = TextEditingController();
    unawaited(_restoreBackendBaseUrl());
  }

  @override
  void dispose() {
    _backendBaseUrlController.dispose();
    super.dispose();
  }

  Map<String, String> get _configValues => <String, String>{
        "EFFECTIVE_BACKEND_BASE_URL": _effectiveBackendBaseUrl,
        "POLYPHONY_BACKEND_BASE_URL (build-time)":
            PolyphonyConfig.backendBaseUrl,
        "AUTH0_DOMAIN": PolyphonyConfig.auth0Domain,
        "AUTH0_NATIVE_CLIENT_ID": PolyphonyConfig.auth0NativeClientId,
        "AUTH0_WEB_CLIENT_ID": PolyphonyConfig.auth0WebClientId,
        "AUTH0_AUDIENCE": PolyphonyConfig.auth0Audience,
        "AUTH0_SCOPES": PolyphonyConfig.auth0Scopes,
        "AUTH0_MOBILE_REDIRECT_URI": PolyphonyConfig.auth0MobileRedirectUri,
        "AUTH0_DESKTOP_REDIRECT_URI": PolyphonyConfig.auth0DesktopRedirectUri,
        "SENTRY_ENABLED": PolyphonyConfig.sentryEnabled.toString(),
        "SENTRY_ENVIRONMENT": PolyphonyConfig.sentryEnvironment,
        "SENTRY_RELEASE": PolyphonyConfig.sentryRelease,
        "SENTRY_TRACES_SAMPLE_RATE":
            PolyphonyConfig.sentryTracesSampleRate().toString(),
      };

  Future<void> _restoreBackendBaseUrl() async {
    final preferencesStore = context.read<PreferencesStore>();
    final resolvedBaseUrl = await resolveBackendBaseUrl(
      preferencesStore: preferencesStore,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _effectiveBackendBaseUrl = resolvedBaseUrl;
      _backendBaseUrlController.text = resolvedBaseUrl;
    });
  }

  Future<void> _saveBackendBaseUrl() async {
    final preferencesStore = context.read<PreferencesStore>();
    final rawBaseUrl = _backendBaseUrlController.text.trim();

    if (rawBaseUrl.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backend URL cannot be empty.")),
      );
      return;
    }

    final parsedUri = Uri.tryParse(rawBaseUrl);
    final hasValidScheme = parsedUri != null &&
        (parsedUri.scheme == "http" || parsedUri.scheme == "https") &&
        parsedUri.hasAuthority;

    if (!hasValidScheme) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Backend URL must be an absolute http/https URL."),
        ),
      );
      return;
    }

    setState(() {
      _isSavingBackendBaseUrl = true;
    });

    try {
      final normalizedBaseUrl = normalizeBackendBaseUrl(rawBaseUrl);
      await preferencesStore.writeBackendBaseUrlOverride(normalizedBaseUrl);
      _updateBackendBaseUrlInDi(normalizedBaseUrl);

      if (!mounted) {
        return;
      }

      setState(() {
        _effectiveBackendBaseUrl = normalizedBaseUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Backend URL saved for this device profile."),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save backend URL: $error")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBackendBaseUrl = false;
        });
      }
    }
  }

  Future<void> _resetBackendBaseUrl() async {
    final preferencesStore = context.read<PreferencesStore>();

    setState(() {
      _isSavingBackendBaseUrl = true;
    });

    try {
      await preferencesStore.clearBackendBaseUrlOverride();
      final defaultBaseUrl = normalizeBackendBaseUrl(
        PolyphonyConfig.backendBaseUrl,
      );
      _updateBackendBaseUrlInDi(defaultBaseUrl);

      if (!mounted) {
        return;
      }

      setState(() {
        _effectiveBackendBaseUrl = defaultBaseUrl;
        _backendBaseUrlController.text = defaultBaseUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Backend URL reset to build-time default."),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to reset backend URL: $error")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBackendBaseUrl = false;
        });
      }
    }
  }

  void _updateBackendBaseUrlInDi(String backendBaseUrl) {
    context.read<ValueNotifier<String>>().value = backendBaseUrl;
  }

  Future<void> _copyToken() async {
    await Clipboard.setData(ClipboardData(text: widget.bearerToken));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: SelectableText("Token copied")),
    );
  }

  void _loadMe() {
    context.read<SettingsDeveloperProfileBloc>().add(
          const SettingsDeveloperProfileLoadRequested(),
        );
  }

  List<String> _meLines(SettingsDeveloperProfileLoadedState state) {
    final displayName = state.me.displayName;

    return <String>[
      "user_id: ${state.me.userId}",
      "display_name: ${displayName ?? "<null>"}",
      "issuer: ${state.me.issuer}",
    ];
  }

  String _describeLoadMeError(Exception error) {
    if (error
        case ApiRequestException(:final statusCode, :final responseBody)) {
      final compactBody = responseBody.replaceAll(RegExp(r"\s+"), " ").trim();
      final preview = compactBody.length > 180
          ? "${compactBody.substring(0, 180)}..."
          : compactBody;

      return "Failed to load /me (HTTP $statusCode)${preview.isEmpty ? "" : ": $preview"}";
    }

    return "Failed to load /me: $error";
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, bool>(
      selector: (state) => switch (state) {
        SettingsLoadedState(:final isDeveloperModeEnabled) =>
          isDeveloperModeEnabled,
        SettingsExceptionState(:final isDeveloperModeEnabled) =>
          isDeveloperModeEnabled,
        SettingsInitialState() => false,
      },
      builder: (context, developerOptionsEnabled) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SelectableText(
              "Developer options",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Enable developer options"),
              value: developerOptionsEnabled,
              onChanged: (value) {
                context.read<SettingsBloc>().add(
                      SettingsDeveloperModeToggledRequested(enabled: value),
                    );

                if (value) {
                  _loadMe();
                }
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed:
                    developerOptionsEnabled && widget.bearerToken.isNotEmpty
                        ? () => unawaited(_copyToken())
                        : null,
                child: const SelectableText("Copy token"),
              ),
            ),
            if (developerOptionsEnabled) ...<Widget>[
              const SizedBox(height: 16),
              SelectableText(
                "Backend endpoint",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _backendBaseUrlController,
                enabled: !_isSavingBackendBaseUrl,
                decoration: const InputDecoration(
                  labelText: "Backend base URL",
                  hintText: "https://api.example.com",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(_saveBackendBaseUrl()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    onPressed: _isSavingBackendBaseUrl
                        ? null
                        : () => unawaited(_saveBackendBaseUrl()),
                    child: const Text("Save backend URL"),
                  ),
                  OutlinedButton(
                    onPressed: _isSavingBackendBaseUrl
                        ? null
                        : () => unawaited(_resetBackendBaseUrl()),
                    child: const Text("Reset to default"),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      throw StateError("This is test exception");
                    },
                    child: const Text("Verify Sentry Setup"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SelectableText(
                "Configuration",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._configValues.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText("${entry.key}: ${entry.value}"),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      "/me response",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMe,
                    child: const SelectableText("Refresh /me"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BlocBuilder<SettingsDeveloperProfileBloc,
                  SettingsDeveloperProfileState>(
                builder: (context, state) {
                  return switch (state) {
                    SettingsDeveloperProfileLoadedState() => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _meLines(state)
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SelectableText(line),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    SettingsDeveloperProfileExceptionState(:final error) =>
                      SelectableText(_describeLoadMeError(error)),
                    SettingsDeveloperProfileLoadingState() => const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    SettingsDeveloperProfileInitialState() =>
                      const SelectableText(
                        "Tap \"Refresh /me\" to load current profile data.",
                      ),
                  };
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
