import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

part "settings_developer_profile_event.dart";
part "settings_developer_profile_state.dart";

class SettingsDeveloperProfileBloc
    extends Bloc<SettingsDeveloperProfileEvent, SettingsDeveloperProfileState> {
  SettingsDeveloperProfileBloc({
    required ProfileService profileService,
  })  : _profileService = profileService,
        super(const SettingsDeveloperProfileInitialState()) {
    on<SettingsDeveloperProfileLoadRequested>(
      _onSettingsDeveloperProfileLoadRequested,
    );
  }

  final ProfileService _profileService;

  Future<void> _onSettingsDeveloperProfileLoadRequested(
    SettingsDeveloperProfileLoadRequested event,
    Emitter<SettingsDeveloperProfileState> emit,
  ) async {
    emit(const SettingsDeveloperProfileLoadingState());

    final meResult = await _profileService.getMe();

    switch (meResult) {
      case Ok(:final value):
        emit(SettingsDeveloperProfileLoadedState(me: value));
      case Error(:final error):
        emit(SettingsDeveloperProfileExceptionState(error: error));
    }
  }
}
