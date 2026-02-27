import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "profile_event.dart";
part "profile_state.dart";

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required ProfileRepo profileRepo})
      : _profileRepo = profileRepo,
        super(const ProfileInitialState()) {
    on<LoadProfileRequested>(_onLoadProfileRequested);
    on<UpdateDisplayNameRequested>(_onUpdateDisplayNameRequested);
  }

  final ProfileRepo _profileRepo;

  Future<void> _onLoadProfileRequested(
    LoadProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoadingState());

    final profileResult = await _profileRepo.getMe(
      baseUrl: event.baseUrl.trim(),
    );

    switch (profileResult) {
      case Ok(:final value):
        emit(ProfileLoadedState(
          userId: value.userId,
          displayName: value.displayName,
        ));
      case Error(:final error):
        emit(ProfileExceptionState(error: error));
    }
  }

  Future<void> _onUpdateDisplayNameRequested(
    UpdateDisplayNameRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);
    final trimmedDisplayName = event.displayName.trim();

    if (loadedState == null) {
      emit(ProfileExceptionState(
        error:
            Exception("Profile must be loaded before updating display name."),
      ));
      return;
    }

    if (trimmedDisplayName.isEmpty) {
      emit(ProfileValidationFailedState(
        issue: ProfileValidationIssue.displayNameRequired,
        userId: loadedState.userId,
        displayName: loadedState.displayName,
      ));
      return;
    }

    emit(const ProfileLoadingState());

    final updateResult = await _profileRepo.updateDisplayName(
      baseUrl: event.baseUrl.trim(),
      displayName: trimmedDisplayName,
    );

    switch (updateResult) {
      case Ok(:final value):
        emit(ProfileLoadedState(
          userId: value.userId,
          displayName: value.displayName,
        ));
      case Error(:final error):
        emit(ProfileExceptionState(error: error));
    }
  }

  ProfileLoadedDataState? _loadedStateOrNull(ProfileState profileState) {
    return switch (profileState) {
      ProfileLoadedDataState() => profileState,
      _ => null,
    };
  }
}
