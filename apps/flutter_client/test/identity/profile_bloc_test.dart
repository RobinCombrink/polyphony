import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<ProfileBloc, ProfileState>(
    "loads profile with no display name",
    build: () => ProfileBloc(
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
      ),
    ),
    act: (bloc) => bloc.add(const LoadProfileRequested()),
    expect: () => <Matcher>[
      isA<ProfileLoadingState>(),
      isA<ProfileLoadedState>()
          .having((state) => state.userId, "user id", fixture.ownerUserId)
          .having((state) => state.displayName, "display name", isNull),
    ],
  );

  blocTest<ProfileBloc, ProfileState>(
    "emits validation failed when display name is empty",
    build: () => ProfileBloc(
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
      ),
    ),
    act: (bloc) {
      bloc
        ..add(const LoadProfileRequested())
        ..add(const UpdateDisplayNameRequested(
          displayName: "   ",
        ));
    },
    expect: () => <Matcher>[
      isA<ProfileLoadingState>(),
      isA<ProfileLoadedState>(),
      isA<ProfileValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        ProfileValidationIssue.displayNameRequired,
      ),
    ],
  );

  blocTest<ProfileBloc, ProfileState>(
    "updates display name successfully",
    build: () => ProfileBloc(
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
      ),
    ),
    act: (bloc) {
      bloc
        ..add(const LoadProfileRequested())
        ..add(const UpdateDisplayNameRequested(
          displayName: "Polyphony User",
        ));
    },
    expect: () => <Matcher>[
      isA<ProfileLoadingState>(),
      isA<ProfileLoadedState>(),
      isA<ProfileLoadingState>(),
      isA<ProfileLoadedState>().having(
        (state) => state.displayName,
        "display name",
        "Polyphony User",
      ),
    ],
  );
}
