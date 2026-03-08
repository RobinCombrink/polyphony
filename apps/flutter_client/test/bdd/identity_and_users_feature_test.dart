import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  group("Feature: Identity and users", () {
    group("Rule: Authenticated user can manage own profile", () {
      blocTest<ProfileBloc, ProfileState>(
        "Scenario: Profile can be loaded for the authenticated user",
        build: () => ProfileBloc(
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
          currentUserId: fixture.ownerUserId,
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
        "Scenario: Updating display name with blank value is rejected",
        build: () => ProfileBloc(
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
          currentUserId: fixture.ownerUserId,
        ),
        act: (bloc) => bloc
          ..add(const LoadProfileRequested())
          ..add(const UpdateDisplayNameRequested(displayName: "   ")),
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
        "Scenario: Authenticated user can update display name",
        build: () => ProfileBloc(
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
          currentUserId: fixture.ownerUserId,
        ),
        act: (bloc) => bloc
          ..add(const LoadProfileRequested())
          ..add(
              const UpdateDisplayNameRequested(displayName: "Polyphony User")),
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
    });
  });
}
