import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";

SectionStatus? buildProfileSectionStatus(ProfileState state) {
  if (state is ProfileValidationFailedState) {
    return switch (state.issue) {
      ProfileValidationIssue.displayNameRequired => const SectionStatus(
          message: "Display name is required.",
          isError: true,
        ),
    };
  }

  if (state is ProfileExceptionState) {
    return SectionStatus(
      message: "Profile operation failed: ${state.error}",
      isError: true,
    );
  }

  if (state is ProfileLoadedDataState && state.displayName.isEmpty) {
    return const SectionStatus(
      message: "Set your display name to finish setup.",
      isError: false,
    );
  }

  return null;
}
