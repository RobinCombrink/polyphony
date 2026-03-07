Feature: Channel messages
  As an authenticated user
  I want to create and manage messages in channels
  So that chat history stays accurate and moderated by ownership

  Rule: Authenticated user manages messages in owned channels
    Background:
      Given an authenticated user exists

    Scenario: Authenticated user can create a message in server channel
      Given a channel exists in server "Test" for the authenticated user
      When the user posts a message in channel "general"
      Then listing messages for channel "general" includes the new message

    Scenario: Authenticated user can edit their message in a server channel
      Given a channel exists in server "Test" for the authenticated user
      And the user already has a message in channel "general"
      When the user edits the message in channel "general"
      Then listing messages for channel "general" returns the updated content

    Scenario: Authenticated user can delete their message in a server channel
      Given a channel exists in server "Test" for the authenticated user
      And the user already has a message in channel "general"
      When the user deletes the message in channel "general"
      Then listing messages for channel "general" does not include the deleted message

    Scenario: Updating a missing message reports that it does not exist
      Given a channel exists in server "Test" for the authenticated user
      When the user edits a message that does not exist in channel "general"
      Then the action fails because the message does not exist

    Scenario: Updating a message in a missing channel reports that it does not exist
      When the user edits a message in a channel that does not exist
      Then the action fails because the channel does not exist

    Scenario: Deleting a missing message reports that it does not exist
      Given a channel exists in server "Test" for the authenticated user
      When the user deletes a message that does not exist in channel "general"
      Then the action fails because the message does not exist

    Scenario: Deleting a message in a missing channel reports that it does not exist
      When the user deletes a message in a channel that does not exist
      Then the action fails because the channel does not exist

    Scenario: Posting a message in a voice channel is rejected
      Given a voice channel exists in server "Test" for the authenticated user
      When the user posts a message in voice channel "voice-lobby"
      Then posting is denied because channel "voice-lobby" does not support messaging

  Rule: Distinct named users enforce message ownership and membership
    Scenario: Authenticated user cannot edit another user's message
      Given a channel exists in a server shared with another user
      And another user already has a message in channel "shared-channel"
      When the authenticated user edits the other user's message in channel "shared-channel"
      Then the edit is denied

    Scenario: Authenticated user cannot delete another user's message
      Given a channel exists in a server shared with another user
      And another user already has a message in channel "shared-channel"
      When the authenticated user deletes the other user's message in channel "shared-channel"
      Then the delete is denied

    Scenario: Non-member cannot list messages in another server's channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a channel exists in server "Test" owned by "Olivia"
      When "Noah" lists messages in channel "shared-channel"
      Then message listing is denied
