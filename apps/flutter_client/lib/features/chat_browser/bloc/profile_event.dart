part of "profile_bloc.dart";

sealed class ProfileEvent {
  const ProfileEvent();
}

final class LoadProfileRequested extends ProfileEvent {
  const LoadProfileRequested();
}

final class UpdateDisplayNameRequested extends ProfileEvent {
  const UpdateDisplayNameRequested({
    required this.displayName,
  });

  final String displayName;
}
