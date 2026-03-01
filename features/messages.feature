Feature: Backend API channel messages
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

  Scenario: Updating a missing message returns not found
    Given an authenticated user exists
    And a channel exists in the user's server
    When the user edits a message that does not exist in that channel
    Then the message is reported as not found

  Scenario: Updating a message in a missing channel returns not found
    Given an authenticated user exists
    When the user edits a message in a channel that does not exist
    Then the channel is reported as not found

  Scenario: Deleting a missing message returns not found
    Given an authenticated user exists
    And a channel exists in the user's server
    When the user deletes a message that does not exist in that channel
    Then the message is reported as not found

  Scenario: Deleting a message in a missing channel returns not found
    Given an authenticated user exists
    When the user deletes a message in a channel that does not exist
    Then the channel is reported as not found
