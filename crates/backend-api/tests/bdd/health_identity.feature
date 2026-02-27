Feature: Health and identity
  API health checks and authenticated identity lookup.

  Scenario: Health endpoint returns 200
    Given the backend API is started
    When a client requests GET /health
    Then the response status is 200

  Scenario: Authenticated me endpoint returns no display name for first login
    Given a seeded user exists
    And the user is authenticated with a valid bearer token
    When the user requests GET /api/v1/me
    Then the response status is 200
    And the payload field user_id equals the seeded user subject

  Scenario: Authenticated user updates display name
    Given a seeded user exists
    And the user is authenticated with a valid bearer token
    When the user requests PATCH /api/v1/me with a new display name
    Then the response status is 200
    And the payload field display_name equals the requested display name
