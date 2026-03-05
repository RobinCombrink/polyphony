Feature: Voice sessions
  As an authenticated user
  I want to join voice channels
  So that I can participate in voice conversations

  Scenario: Authenticated user can join an existing voice channel
    Given an authenticated user exists
    And a voice channel exists in the user's server
    When I connect to voice for that channel
    Then the connection succeeds
    And connection details are returned

  Scenario: Connecting to voice in a missing channel reports that it does not exist
    Given an authenticated user exists
    When I connect to voice for a missing channel
    Then the user is told the channel does not exist

  Scenario: Non-member cannot connect to voice in another server's channel
    Given a server owner exists
    And a second authenticated user exists
    And a voice channel exists in the owner's server
    When the second user connects to voice for that channel
    Then voice connection is forbidden

  Scenario: Server member can join voice in a shared channel
    Given a server owner exists
    And a second authenticated user exists
    And a voice channel exists in the owner's server
    And the first user adds the second user as a member
    When the second user connects to voice for that channel
    Then the connection succeeds
    And connection details are returned

  Scenario: Connecting to voice in a text channel is rejected
    Given an authenticated user exists
    And a text channel exists in the user's server
    When I connect to voice for that text channel
    Then the user is told that channel type is incompatible with voice

  Scenario: Connecting to text session in a voice channel is rejected
    Given an authenticated user exists
    And a voice channel exists in the user's server
    When I connect to text session for that voice channel
    Then the user is told that channel type is incompatible with text sessions
