import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";

class DisplayNameBannerWidget extends StatelessWidget {
  const DisplayNameBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, profileState) {
        final displayName = switch (profileState) {
          ProfileLoadedDataState(:final displayName) => displayName,
          _ => null,
        };

        return Text("Display name: ${displayName ?? "Not set"}");
      },
    );
  }
}
