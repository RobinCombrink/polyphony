Feature: Service health and identity
  As a local developer
  I want to verify service health and identity resolution
  So that I can trust local-first development before dev rollout

  Scenario: Service reports healthy
    Given the backend service is running
    When I check service health
    Then the service is reported as healthy
    And the service name is returned

  Scenario: Authenticated user can view identity details
    Given an authenticated user exists
    When the user views their own identity
    Then identity details are returned
    And the identity includes the user's external reference
