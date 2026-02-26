Feature: Health and identity
  API health checks and authenticated identity lookup.

  Scenario: Health endpoint returns 200
    Given the backend API is started
    When a client requests GET /health
    Then the response status is 200

  Scenario: Authenticated me endpoint returns seeded subject
    Given a seeded user exists
    And the user is authenticated with a valid bearer token
    When the user requests GET /api/v1/me
    Then the response status is 200
    And the payload field user_id equals the seeded user subject
