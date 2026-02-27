part of "profile_bloc.dart";

sealed class ProfileEvent {
  const ProfileEvent();
}

final class LoadProfileRequested extends ProfileEvent {
  const LoadProfileRequested({required this.baseUrl});

  final String baseUrl;
}

final class UpdateDisplayNameRequested extends ProfileEvent {
  const UpdateDisplayNameRequested({
    required this.baseUrl,
    required this.displayName,
  });

  final String baseUrl;
  final String displayName;
}
