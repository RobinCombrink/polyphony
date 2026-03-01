Feature: Backend API identity and user lookup
  As an authenticated user
  I want to manage my profile and resolve user identities
  So that user information is accurate and retrievable

  Scenario: Authenticated user can update display name
    Given an authenticated user exists
    When I update my display name
    Then the update succeeds
    And the returned profile includes the updated display name
    And viewing my identity again includes the updated display name

  Scenario: Existing user can be looked up by id
    Given an authenticated user exists
    And the authenticated user has an updated display name
    When I look up that user by id
    Then the lookup succeeds
    And the result includes the user id and display name

  Scenario: Looking up a missing user returns not found
    Given an authenticated user exists
    When I look up a user id that does not exist
    Then the user is reported as not found

  Scenario: Looking up a user with an invalid token returns unauthorized
    Given an authenticated user exists
    When identity lookup is attempted without valid authentication
    Then the request is unauthorized
