Feature: Backend API voice sessions
  As an authenticated user
  I want to request voice connection credentials for channels
  So that the client can connect directly to LiveKit

  Scenario: Authenticated user can connect to voice in existing voice channel
    Given an authenticated user exists
    And a voice channel exists in the user's server
    When I connect to voice for that channel
    Then the connection succeeds
    And voice connection details are returned

  Scenario: Connecting to voice in a missing channel returns not found
    Given an authenticated user exists
    When I connect to voice for a missing channel
    Then the channel is reported as not found

  Scenario: Non-member cannot connect to voice in another server's channel
    Given a server owner exists
    And a second authenticated user exists
    And a voice channel exists in the owner's server
    When the second user connects to voice for that channel
    Then voice connection is forbidden
