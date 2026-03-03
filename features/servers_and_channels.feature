Feature: Backend API servers and channels
  As an authenticated user
  I want to create and manage servers and channels
  So that conversations can be organized by topic

  Scenario: Authenticated user can create a server
    Given an authenticated user exists
    When the user creates a server
    Then the server is created successfully

  Scenario: Authenticated user can list their servers
    Given an authenticated user exists
    And the user already owns a server
    When the user lists their servers
    Then the owned server is included in the server list

  Scenario: Authenticated user can create a server channel
    Given an authenticated user exists
    And the user already owns a server
    When the user creates a channel in that server
    Then the server channel is created successfully

  Scenario: Authenticated user can list channels in server
    Given an authenticated user exists
    And a channel exists in the user's server
    When the user lists channels in that server
    Then the channel is included in the channel list

  Scenario: Server owner can update a channel name
    Given an authenticated user exists
    And a channel exists in the user's server
    When the server owner updates the channel name
    Then listing channels in that server includes the updated name

  Scenario: Non-owner cannot update a channel name
    Given an authenticated user exists
    And a channel exists in a server owned by another user
    When the non-owner attempts to update the channel name
    Then the update is forbidden

  Scenario: Updating a missing channel returns not found
    Given an authenticated user exists
    When the user updates a channel that does not exist
    Then the channel is reported as not found

  Scenario: Server owner can add a server member
    Given an authenticated user exists
    And the user already owns a server
    When the server owner adds another user as a member
    Then the server membership is created successfully

  Scenario: Added server member can list the shared server
    Given a server owner exists
    And a second authenticated user exists
    And the owner already has a server
    And the first user adds the second user as a member
    When the second user lists their servers
    Then the shared server is included in their server list

  Scenario: Non-member cannot list channels in a server they do not belong to
    Given a server owner exists
    And a second authenticated user exists
    And the owner already has a server
    And a channel exists in the owner's server
    When the second user lists channels in that server
    Then listing channels is forbidden

  Scenario: Non-owner cannot add a server member
    Given a server owner exists
    And a second authenticated user exists
    And the owner already has a server
    And the first user adds the second user as a member
    When the second user tries to add a different user to that server
    Then the add-member action is forbidden

  Scenario: Server owner can delete a server
    Given an authenticated user exists
    And the user already owns a server
    When the server owner deletes that server
    Then the delete succeeds
    And listing servers for that user returns no servers

  Scenario: Non-owner cannot delete a server
    Given a server owner exists
    And a second authenticated user exists
    And the owner already has a server
    And the first user adds the second user as a member
    When the second user deletes that server
    Then the delete is forbidden

  Scenario: Deleting a missing server returns not found
    Given an authenticated user exists
    When the user deletes a server that does not exist
    Then the server is reported as not found

  Scenario: Server owner can delete a channel
    Given an authenticated user exists
    And a channel exists in the user's server
    When the server owner deletes that channel
    Then the delete succeeds
    And listing channels in that server returns no channels

  Scenario: Non-owner cannot delete a channel
    Given a server owner exists
    And a second authenticated user exists
    And a channel exists in the owner's server
    And the first user adds the second user as a member
    When the second user deletes that channel
    Then the delete is forbidden

  Scenario: Deleting a missing channel returns not found
    Given an authenticated user exists
    When the user deletes a channel that does not exist
    Then the channel is reported as not found
