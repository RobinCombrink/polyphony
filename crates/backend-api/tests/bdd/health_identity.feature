Feature: Health and identity
  Service readiness and authenticated identity access.

  Scenario: Service reports healthy when it is running
    Given the backend API is started
    When a client checks service health
    Then the service health check succeeds

  Scenario: First authenticated identity view has no display name yet
    Given a seeded user exists
    And the user is authenticated
    When the user views their own identity
    Then the identity request succeeds
    And the identity belongs to the seeded user

  Scenario: Authenticated user updates display name
    Given a seeded user exists
    And the user is authenticated
    When the user updates their display name
    Then the display name update succeeds
    And the updated display name is shown in the identity
