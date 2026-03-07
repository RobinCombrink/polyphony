Feature: Voice sessions
  As an authenticated user
  I want to join voice channels
  So that I can participate in voice conversations

  Rule: Authenticated user connects to compatible channels
    Background:
      Given an authenticated user exists

    Scenario: Authenticated user can join an existing voice channel
      Given a voice channel exists in server "Test" for the authenticated user
      When I connect to voice for channel "voice-lobby"
      Then the connection succeeds
      And the participant can join voice conversation for channel "voice-lobby"

    Scenario: Connecting to voice in a missing channel reports that it does not exist
      When I connect to voice for a missing channel
      Then the action fails because the channel does not exist

    Scenario: Connecting to voice in a text channel is rejected
      Given a text channel exists in server "Test" for the authenticated user
      When I connect to voice for channel "text-lobby"
      Then voice connection is denied for channel "text-lobby" type

    Scenario: Connecting to text session in a voice channel is rejected
      Given a voice channel exists in server "Test" for the authenticated user
      When I connect to text session for channel "voice-lobby"
      Then text session connection is denied for channel "voice-lobby" type

  Rule: Distinct named users enforce shared voice access
    Scenario: Non-member cannot connect to voice in another server's channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a voice channel exists in server "Test" owned by "Olivia"
      When "Noah" connects to voice for channel "shared-voice"
      Then voice connection is denied

    Scenario: Server member can join voice in a shared channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a voice channel exists in server "Test" owned by "Olivia"
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" connects to voice for channel "shared-voice"
      Then the connection succeeds
      And the participant can join voice conversation for channel "shared-voice"
