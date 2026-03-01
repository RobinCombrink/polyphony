Feature: Backend API servers and channels
  As an authenticated user
  I want to create and manage servers and channels
  So that conversations can be organized by topic

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

  Scenario: Server owner can update a channel name
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When I update the seeded channel name
    Then listing channels in that server includes the updated channel name

  Scenario: Non-owner cannot update a channel name
    Given an authenticated user exists from the EntitySeeder
    And a seeded server channel exists for that user
    When a different authenticated user updates the seeded channel name
    Then the response status is 403

  Scenario: Updating a missing channel returns not found
    Given an authenticated user exists from the EntitySeeder
    When I update a missing channel name
    Then the response status is 404
