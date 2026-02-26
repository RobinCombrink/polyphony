Feature: Servers and channels
  Authenticated users can create and list servers and channels.

  Background:
    Given an authenticated user with a valid bearer token

  Scenario: Create server returns created status and id
    When the user creates a server
    Then the response status is 201
    And the payload contains a server id

  Scenario: Created server is listed
    Given the user created a server
    When the user lists servers
    Then the response status is 200
    And the response contains exactly 1 server
    And the listed server name matches the created server

  Scenario: Create channel in existing server returns created status and id
    Given the user created a server
    When the user creates a channel in that server
    Then the response status is 201
    And the payload contains a channel id
    And the payload server_id matches the target server id

  Scenario: Created channel is listed for server
    Given the user created a server
    And the user created a channel in that server
    When the user lists channels for that server
    Then the response status is 200
    And the response contains exactly 1 channel
    And the listed channel name matches the created channel

  Scenario: Non-owner cannot add a user to a server
    Given the owner created a server
    And a different authenticated member exists
    When the non-owner member adds a user to that server
    Then the response status is 403
