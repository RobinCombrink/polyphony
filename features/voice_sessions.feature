Feature: Voice sessions
  As an authenticated user
  I want to join voice channels
  So that I can participate in voice conversations

  Rule: Authenticated user connects to compatible channels
    Background:
      Given an authenticated user exists

    Scenario: Authenticated user can join an existing voice channel
      Given a voice channel exists in server "Test" for the authenticated user
      When I connect to voice for that channel
      Then the connection succeeds
      And the participant can join that voice conversation

    Scenario: Connecting to voice in a missing channel reports that it does not exist
      When I connect to voice for a missing channel
      Then the action fails because the channel does not exist

    Scenario: Connecting to voice in a text channel is rejected
      Given a text channel exists in server "Test" for the authenticated user
      When I connect to voice for that text channel
      Then voice connection is denied for that channel type

    Scenario: Connecting to text session in a voice channel is rejected
      Given a voice channel exists in server "Test" for the authenticated user
      When I connect to text session for that voice channel
      Then text session connection is denied for that channel type

  Rule: Distinct named users enforce shared voice access
    Scenario: Non-member cannot connect to voice in another server's channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a voice channel exists in server "Test" owned by "Olivia"
      When "Noah" connects to voice for that channel
      Then voice connection is denied

    Scenario: Server member can join voice in a shared channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a voice channel exists in server "Test" owned by "Olivia"
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" connects to voice for that channel
      Then the connection succeeds
      And the participant can join that voice conversation
