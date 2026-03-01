Feature: Backend API voice sessions
  As an authenticated user
  I want to connect to voice sessions in channels
  So that voice participation stays consistent across channels

  Scenario: Authenticated user can connect to voice in existing channel
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When I connect to voice for that channel
    Then the response status is 200
    And the response includes livekit connection credentials

  Scenario: Connecting to voice in a missing channel returns not found
    Given an authenticated user exists from the EntitySeeder
    When I connect to voice for a missing channel
    Then the response status is 404

  Scenario: Connecting to a second channel moves the user from the first channel
    Given an authenticated user exists from the EntitySeeder
    And a seeded server exists for that user
    And two seeded channels exist in that server
    When I connect to voice for the first channel
    And I connect to voice for the second channel
    Then listing voice sessions for the first channel returns no participants
    And listing voice sessions for the second channel includes the authenticated user
