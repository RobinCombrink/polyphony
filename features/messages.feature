Feature: Backend API channel messages
  As an authenticated user
  I want to create and manage messages in channels
  So that chat history stays accurate and moderated by ownership

  Scenario: Authenticated user can create a message in server channel
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When I post a seeded message in that channel
    Then listing messages for that channel returns the seeded message

  Scenario: Authenticated user can edit their message in a server channel
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    And a seeded message exists in that channel
    When I edit the seeded message content
    Then listing messages for that channel returns the updated content

  Scenario: Authenticated user can delete their message in a server channel
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    And a seeded message exists in that channel
    When I delete the seeded message
    Then listing messages for that channel does not include the deleted message

  Scenario: Authenticated user cannot edit another user's message
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    And a seeded message exists in that channel
    When a different authenticated user edits the seeded message content
    Then the response status is 403

  Scenario: Authenticated user cannot delete another user's message
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    And a seeded message exists in that channel
    When a different authenticated user deletes the seeded message
    Then the response status is 403

  Scenario: Updating a missing message returns not found
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When I edit a missing message in that channel
    Then the response status is 404

  Scenario: Updating a message in a missing channel returns not found
    Given an authenticated user exists from the EntitySeeder
    When I edit a message in a missing channel
    Then the response status is 404

  Scenario: Deleting a missing message returns not found
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When I delete a missing message in that channel
    Then the response status is 404

  Scenario: Deleting a message in a missing channel returns not found
    Given an authenticated user exists from the EntitySeeder
    When I delete a message in a missing channel
    Then the response status is 404
