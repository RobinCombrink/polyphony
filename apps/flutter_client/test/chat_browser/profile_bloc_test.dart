import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/profile_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<ProfileBloc, ProfileState>(
    "loads profile with no display name",
    build: () => ProfileBloc(
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerSubject,
        initialDisplayName: null,
      ),
    ),
    act: (bloc) => bloc.add(
      const LoadProfileRequested(baseUrl: "http://127.0.0.1:5067"),
    ),
    expect: () => <Matcher>[
      isA<ProfileLoadingState>(),
      isA<ProfileLoadedState>()
          .having((state) => state.userId, "user id", fixture.ownerSubject)
          .having((state) => state.displayName, "display name", isNull),
    ],
  );

  blocTest<ProfileBloc, ProfileState>(
    "emits validation failed when display name is empty",
    build: () => ProfileBloc(
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerSubject,
        initialDisplayName: null,
      ),
    ),
    act: (bloc) {
      bloc
        ..add(const LoadProfileRequested(baseUrl: "http://127.0.0.1:5067"))
        ..add(const UpdateDisplayNameRequested(
          baseUrl: "http://127.0.0.1:5067",
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
        userId: fixture.ownerSubject,
        initialDisplayName: null,
      ),
    ),
    act: (bloc) {
      bloc
        ..add(const LoadProfileRequested(baseUrl: "http://127.0.0.1:5067"))
        ..add(const UpdateDisplayNameRequested(
          baseUrl: "http://127.0.0.1:5067",
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
