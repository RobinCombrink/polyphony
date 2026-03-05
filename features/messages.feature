Feature: Channel messages
  As an authenticated user
  I want to create and manage messages in channels
  So that chat history stays accurate and moderated by ownership

  Scenario: Authenticated user can create a message in server channel
    Given an authenticated user exists
    And a channel exists in the user's server
    When the user posts a message in that channel
    Then listing messages for that channel includes the new message

  Scenario: Authenticated user can edit their message in a server channel
    Given an authenticated user exists
    And a channel exists in the user's server
    And the user already has a message in that channel
    When the user edits that message
    Then listing messages for that channel returns the updated content

  Scenario: Authenticated user can delete their message in a server channel
    Given an authenticated user exists
    And a channel exists in the user's server
    And the user already has a message in that channel
    When the user deletes that message
    Then listing messages for that channel does not include the deleted message

  Scenario: Authenticated user cannot edit another user's message
    Given an authenticated user exists
    And a channel exists in a server shared with another user
    And another user already has a message in that channel
    When the authenticated user edits the other user's message
    Then the edit is forbidden

  Scenario: Authenticated user cannot delete another user's message
    Given an authenticated user exists
    And a channel exists in a server shared with another user
    And another user already has a message in that channel
    When the authenticated user deletes the other user's message
    Then the delete is forbidden

  Scenario: Non-member cannot list messages in another server's channel
    Given a server owner exists
    And a second authenticated user exists
    And a channel exists in the owner's server
    When the second user lists messages in that channel
    Then listing messages is forbidden

  Scenario: Updating a missing message reports that it does not exist
    Given an authenticated user exists
    And a channel exists in the user's server
    When the user edits a message that does not exist in that channel
    Then the user is told the message does not exist

  Scenario: Updating a message in a missing channel reports that it does not exist
    Given an authenticated user exists
    When the user edits a message in a channel that does not exist
    Then the user is told the channel does not exist

  Scenario: Deleting a missing message reports that it does not exist
    Given an authenticated user exists
    And a channel exists in the user's server
    When the user deletes a message that does not exist in that channel
    Then the user is told the message does not exist

  Scenario: Deleting a message in a missing channel reports that it does not exist
    Given an authenticated user exists
    When the user deletes a message in a channel that does not exist
    Then the user is told the channel does not exist

  Scenario: Posting a message in a voice channel is rejected
    Given an authenticated user exists
    And a voice channel exists in the user's server
    When the user posts a message in that voice channel
    Then the user is told that channel type is incompatible with messaging
