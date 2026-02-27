import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

class ProfileRepository implements ProfileRepo {
  const ProfileRepository({required ProfileService profileService})
      : _profileService = profileService;

  final ProfileService _profileService;

  @override
  Future<Result<UserProfile>> getMe({required String baseUrl}) async {
    final serviceResult = await _profileService.getMe(baseUrl: baseUrl);

    return switch (serviceResult) {
      Ok<ApiMe>(:final value) => Ok<UserProfile>(value.toDomainModel()),
      Error<ApiMe>(:final error) => Error<UserProfile>(error),
    };
  }

  @override
  Future<Result<UserProfile>> updateDisplayName({
    required String baseUrl,
    required String displayName,
  }) async {
    final serviceResult = await _profileService.updateDisplayName(
      baseUrl: baseUrl,
      displayName: displayName,
    );

    return switch (serviceResult) {
      Ok<ApiMe>(:final value) => Ok<UserProfile>(value.toDomainModel()),
      Error<ApiMe>(:final error) => Error<UserProfile>(error),
    };
  }
}
