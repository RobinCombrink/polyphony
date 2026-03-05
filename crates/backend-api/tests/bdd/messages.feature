Feature: Channel messages
  Users can create, update, and delete messages in channels with ownership rules.

  Background:
    Given an authenticated user
    And the user created a server and channel

  Scenario: Create message is listed
    When the user creates a message in the channel
    Then the message creation succeeds
    When the user lists channel messages
    Then the response contains exactly 1 message
    And the listed message content matches the created message

  Scenario: Update message changes listed content
    Given the user created a message in the channel
    When the user updates the message content
    Then the message update succeeds
    When the user lists channel messages
    Then the response contains exactly 1 message
    And the listed message content equals the updated content

  Scenario: Delete message removes it from listing
    Given the user created a message in the channel
    When the user deletes the message
    Then the message deletion succeeds
    When the user lists channel messages
    Then the response contains 0 messages

  Scenario: Updating another user's message is forbidden
    Given one authenticated owner user created a message
    And another authenticated user accesses the same channel
    When the other user updates the owner's message
    Then the update is forbidden

  Scenario: Deleting another user's message is forbidden
    Given one authenticated owner user created a message
    And another authenticated user accesses the same channel
    When the other user deletes the owner's message
    Then the delete is forbidden

  Scenario: Non-member cannot list messages in another server's channel
    Given a server owner exists
    And a second authenticated user exists
    And a channel exists in the owner's server
    When the second user lists messages in that channel
    Then listing messages is forbidden

  Scenario: Updating a missing message reports that it does not exist
    When the user updates a missing message id in an existing channel
    Then the user is told the message does not exist

  Scenario: Updating a message in a missing channel reports that it does not exist
    When the user updates a message in a missing channel
    Then the user is told the channel does not exist

  Scenario: Deleting a missing message reports that it does not exist
    When the user deletes a missing message id in an existing channel
    Then the user is told the message does not exist

  Scenario: Deleting a message in a missing channel reports that it does not exist
    When the user deletes a message in a missing channel
    Then the user is told the channel does not exist

  Scenario: Posting a message in a voice channel is rejected
    Given a voice channel exists for the authenticated user
    When the user posts a message in that voice channel
    Then the user is told that channel type is incompatible with messaging
