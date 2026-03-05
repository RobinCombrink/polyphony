Feature: Voice sessions
  Users join voice channels to participate in conversations.

  Background:
    Given an authenticated user

  Scenario: User can join voice in a valid voice channel
    Given the user created a server and channel
    When the user connects to channel voice
    Then the voice connection succeeds
    And connection details are returned for the selected channel and user

  Scenario: Connecting voice in a missing channel reports that it does not exist
    When the user connects voice in a missing channel
    Then the user is told the channel does not exist
