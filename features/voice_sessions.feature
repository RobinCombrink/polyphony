Feature: Voice sessions
  As an authenticated user
  I want to join voice channels
  So that I can participate in voice conversations

  Rule: Authenticated user connects to compatible channels
    Background:
      Given an authenticated user exists

    Scenario: Authenticated user can join an existing voice channel
      Given a voice channel exists in the user's server
      When I connect to voice for that channel
      Then the connection succeeds
      And connection details are returned

    Scenario: Connecting to voice in a missing channel reports that it does not exist
      When I connect to voice for a missing channel
      Then the user is told the channel does not exist

    Scenario: Connecting to voice in a text channel is rejected
      Given a text channel exists in the user's server
      When I connect to voice for that text channel
      Then the user is told that channel type is incompatible with voice

    Scenario: Connecting to text session in a voice channel is rejected
      Given a voice channel exists in the user's server
      When I connect to text session for that voice channel
      Then the user is told that channel type is incompatible with text sessions

  Rule: Distinct named users enforce shared voice access
    Scenario: Non-member cannot connect to voice in another server's channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a voice channel exists in "Olivia"'s server
      When "Noah" connects to voice for that channel
      Then voice connection is forbidden

    Scenario: Server member can join voice in a shared channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a voice channel exists in "Olivia"'s server
      And "Olivia" adds "Noah" to the server
      When "Noah" connects to voice for that channel
      Then the connection succeeds
      And connection details are returned
