Feature: Backend API identity and user lookup
  As an authenticated user
  I want to manage my profile and resolve user identities
  So that user information is accurate and retrievable

  Scenario: Authenticated user can update display name
    Given an authenticated user exists from the EntitySeeder
    When I update my display name
    Then the response status is 200
    And the response includes the updated display name
    And requesting my identity again includes the updated display name

  Scenario: Existing user can be looked up by id
    Given an authenticated user exists from the EntitySeeder
    And the authenticated user has an updated display name
    When I request GET /api/v1/users/{user_id} with a valid bearer token
    Then the response status is 200
    And the response includes the user id and display name

  Scenario: Looking up a missing user returns not found
    Given an authenticated user exists from the EntitySeeder
    When I request GET /api/v1/users/{missing_user_id} with a valid bearer token
    Then the response status is 404

  Scenario: Looking up a user with an invalid token returns unauthorized
    Given an authenticated user exists from the EntitySeeder
    When I request GET /api/v1/users/{user_id} with an invalid bearer token
    Then the response status is 401
