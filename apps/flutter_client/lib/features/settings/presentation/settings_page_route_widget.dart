import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/chat_browser_settings_page_widget.dart";

class SettingsPageRouteWidget extends StatelessWidget {
  const SettingsPageRouteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authenticationState = context.read<AuthenticationBloc>().state;
    final bearerToken = authenticationState is AuthenticationAuthenticatedState
        ? authenticationState.metadata.bearerToken
        : "";

    final profileState = context.read<ProfileBloc>().state;
    final currentDisplayName = switch (profileState) {
      ProfileLoadedDataState(:final displayName) => displayName,
      _ => null,
    };

    return ChatBrowserSettingsPageWidget(
      bearerToken: bearerToken,
      initialDisplayName: currentDisplayName,
      onSaveDisplayName: (displayName) {
        context.read<ProfileBloc>().add(
              UpdateDisplayNameRequested(displayName: displayName),
            );
      },
    );
  }
}
