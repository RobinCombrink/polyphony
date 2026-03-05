Feature: Voice sessions
  Users join voice channels to participate in conversations.

  Background:
    Given an authenticated user

  Scenario: User can join voice in a valid voice channel
    Given the user created a server and channel
    When the user connects to channel voice
    Then the voice connection succeeds
    And connection details are returned for the selected channel and user

  Scenario: Server member can join voice in a shared channel
    Given a server owner exists
    And a second authenticated user exists
    And a voice channel exists in the owner's server
    And the first user adds the second user as a member
    When the second user connects to voice for that channel
    Then the voice connection succeeds
    And connection details are returned for the selected channel and user

  Scenario: Connecting voice in a missing channel reports that it does not exist
    When the user connects voice in a missing channel
    Then the user is told the channel does not exist
