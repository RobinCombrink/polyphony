Feature: Channel messages
  Users can create, update, and delete messages in channels with ownership rules.

  Background:
    Given an authenticated user with a valid bearer token
    And the user created a server and channel

  Scenario: Create message is listed
    When the user creates a message in the channel
    Then the response status is 201
    When the user lists channel messages
    Then the response contains exactly 1 message
    And the listed message content matches the created message

  Scenario: Update message changes listed content
    Given the user created a message in the channel
    When the user updates the message content
    Then the response status is 200
    When the user lists channel messages
    Then the response contains exactly 1 message
    And the listed message content equals the updated content

  Scenario: Delete message removes it from listing
    Given the user created a message in the channel
    When the user deletes the message
    Then the response status is 204
    When the user lists channel messages
    Then the response contains 0 messages

  Scenario: Updating another user's message is forbidden
    Given one authenticated owner user created a message
    And another authenticated user accesses the same channel
    When the other user updates the owner's message
    Then the response status is 403

  Scenario: Deleting another user's message is forbidden
    Given one authenticated owner user created a message
    And another authenticated user accesses the same channel
    When the other user deletes the owner's message
    Then the response status is 403

  Scenario: Updating missing message returns not found
    When the user updates a missing message id in an existing channel
    Then the response status is 404

  Scenario: Updating message in missing channel returns not found
    When the user updates a message in a missing channel
    Then the response status is 404

  Scenario: Deleting missing message returns not found
    When the user deletes a missing message id in an existing channel
    Then the response status is 404

  Scenario: Deleting message in missing channel returns not found
    When the user deletes a message in a missing channel
    Then the response status is 404
