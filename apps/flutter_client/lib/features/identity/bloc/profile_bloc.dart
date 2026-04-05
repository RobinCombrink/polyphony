import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "profile_event.dart";
part "profile_state.dart";

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required ProfileRepo profileRepo,
    required UserId currentUserId,
  })  : _profileRepo = profileRepo,
        _currentUserId = currentUserId,
        super(const ProfileInitialState()) {
    on<LoadProfileRequested>(_onLoadProfileRequested);
    on<UpdateDisplayNameRequested>(_onUpdateDisplayNameRequested);
  }

  final ProfileRepo _profileRepo;
  final UserId _currentUserId;

  Future<void> _onLoadProfileRequested(
    LoadProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoadingState());

    final profileResult = await _profileRepo.getOne(
      query: GetUserQuery(userId: _currentUserId),
    );

    switch (profileResult) {
      case Ok(:final value):
        emit(ProfileLoadedState(
          userId: value.userId,
          displayName: value.displayName ?? "",
        ));
      case Error(:final error):
        emit(ProfileExceptionState(error: error));
    }
  }

  Future<void> _onUpdateDisplayNameRequested(
    UpdateDisplayNameRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final trimmedDisplayName = event.displayName.trim();
    final loadedState = switch (state) {
      final ProfileLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(
        ProfileExceptionState(
          error: Exception(
            "Profile must be loaded before updating display name.",
          ),
        ),
      );
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

    final updateResult = await _profileRepo.updateOne(
      command: UpdateDisplayNameCommand(
        displayName: trimmedDisplayName,
      ),
    );

    switch (updateResult) {
      case Ok(:final value):
        emit(ProfileLoadedState(
          userId: value.userId,
          displayName: value.displayName ?? "",
        ));
      case Error(:final error):
        emit(ProfileExceptionState(error: error));
    }
  }
}
