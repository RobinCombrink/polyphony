Feature: Backend API health and authenticated identity
  As a local developer
  I want to verify service health and identity resolution
  So that I can trust local-first development before dev rollout

  Scenario: Health endpoint returns ok
    Given the backend API is started
    When I request GET /health
    Then the response status is 200
    And the response contains service name backend-api

  Scenario: Authenticated user endpoint returns Auth0 subject
    Given an authenticated user exists from the EntitySeeder
    When I request GET /api/v1/me with a valid bearer token
    Then the response status is 200
    And the response includes the seeded user subject

  Scenario: Authenticated user can create a server
    Given an authenticated user exists from the EntitySeeder
    When I create a server with a seeded name
    Then the server is created successfully

  Scenario: Authenticated user can list their servers
    Given an authenticated user exists from the EntitySeeder
    And a seeded server exists for that user
    When I list servers for the authenticated user
    Then the seeded server is included in the server list

  Scenario: Authenticated user can create a server channel
    Given an authenticated user exists from the EntitySeeder
    And a seeded server exists for that user
    And I create a channel in that server with a seeded name
    Then the server channel is created successfully

  Scenario: Authenticated user can list channels in server
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When I list channels in that server
    Then the seeded channel is included in the channel list

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
