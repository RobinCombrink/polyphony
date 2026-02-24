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
