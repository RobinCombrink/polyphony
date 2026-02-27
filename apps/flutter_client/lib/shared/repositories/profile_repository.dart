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
  Future<Result<UserProfile>> getOne({required GetProfileQuery query}) async {
    final serviceResult = await _profileService.getMe();

    return switch (serviceResult) {
      Ok<ApiMe>(:final value) => Ok<UserProfile>(value.toDomainModel()),
      Error<ApiMe>(:final error) => Error<UserProfile>(error),
    };
  }

  @override
  Future<Result<UserProfile>> updateOne({
    required UpdateDisplayNameCommand command,
  }) async {
    final serviceResult = await _profileService.updateDisplayName(
      displayName: command.displayName,
    );

    return switch (serviceResult) {
      Ok<ApiMe>(:final value) => Ok<UserProfile>(value.toDomainModel()),
      Error<ApiMe>(:final error) => Error<UserProfile>(error),
    };
  }

  @override
  Future<Result<UserProfile>> getUserById({
    required GetUserProfileByIdQuery query,
  }) async {
    final serviceResult =
        await _profileService.getUserById(userId: query.userId);

    return switch (serviceResult) {
      Ok<ApiUserLookup>(:final value) => Ok<UserProfile>(value.toDomainModel()),
      Error<ApiUserLookup>(:final error) => Error<UserProfile>(error),
    };
  }
}
