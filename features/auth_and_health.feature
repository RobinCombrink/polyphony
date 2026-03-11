Feature: Health and identity access
  As a local developer
  I want to verify service readiness and identity access
  So that I can trust local-first development before dev rollout

  Rule: Service remains healthy
    Scenario: Service reports healthy
      Given the application is running
      When I check health
      Then health is reported as ready
      And service details are visible

  Rule: Authenticated identity is readable
    Background:
      Given an authenticated user exists

    Scenario: Authenticated user can view identity details
      When the user views their own identity
      Then identity details are returned
      And the identity includes the user's external reference

    Scenario: First identity view has no display name yet
      When the user views their own identity
      Then identity details are returned
      And the identity has no display name yet
