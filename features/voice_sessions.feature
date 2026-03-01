Feature: Backend API voice sessions
  As an authenticated user
  I want to connect to voice sessions in channels
  So that voice participation stays consistent across channels

  Scenario: Authenticated user can connect to voice in existing channel
    Given an authenticated user exists
    And a channel exists in the user's server
    When I connect to voice for that channel
    Then the connection succeeds
    And voice connection details are returned

  Scenario: Connecting to voice in a missing channel returns not found
    Given an authenticated user exists
    When I connect to voice for a missing channel
    Then the channel is reported as not found

  Scenario: Connecting to a second channel moves the user from the first channel
    Given an authenticated user exists
    And a server exists for that user
    And two channels exist in that server
    When I connect to voice for the first channel
    And I connect to voice for the second channel
    Then listing voice sessions for the first channel returns no participants
    And listing voice sessions for the second channel includes the authenticated user
