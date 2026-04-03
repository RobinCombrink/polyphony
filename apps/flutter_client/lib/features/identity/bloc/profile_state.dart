part of "profile_bloc.dart";

enum ProfileValidationIssue {
  displayNameRequired,
}

sealed class ProfileState {
  const ProfileState();
}

final class ProfileInitialState extends ProfileState {
  const ProfileInitialState();
}

final class ProfileLoadingState extends ProfileState {
  const ProfileLoadingState();
}

sealed class ProfileLoadedDataState extends ProfileState {
  const ProfileLoadedDataState({
    required this.userId,
    required this.displayName,
  });

  final UserId userId;
  final String? displayName;
}

final class ProfileLoadedState extends ProfileLoadedDataState {
  const ProfileLoadedState({
    required super.userId,
    required super.displayName,
  });
}

final class ProfileValidationFailedState extends ProfileLoadedDataState {
  const ProfileValidationFailedState({
    required this.issue,
    required super.userId,
    required super.displayName,
  });

  final ProfileValidationIssue issue;
}

final class ProfileExceptionState extends ProfileState {
  const ProfileExceptionState({required this.error});

  final Exception error;
}
