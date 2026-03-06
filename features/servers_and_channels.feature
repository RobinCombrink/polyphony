Feature: Servers and channels
  As an authenticated user
  I want to create and manage servers and channels
  So that conversations can be organized by topic

  Rule: Authenticated user manages owned servers and channels
    Background:
      Given an authenticated user exists

    Scenario: Authenticated user can create a server
      When the user creates a server
      Then the server is created successfully

    Scenario: Authenticated user can list their servers
      Given the user already owns a server
      When the user lists their servers
      Then the owned server is included in the server list

    Scenario: Authenticated user can create a server channel
      Given the user already owns a server
      When the user creates a channel in that server
      Then the server channel is created successfully

    Scenario: Authenticated user can list channels in server
      Given a channel exists in the user's server
      When the user lists channels in that server
      Then the channel is included in the channel list

    Scenario: Server owner can update a channel name
      Given a channel exists in the user's server
      When the server owner updates the channel name
      Then listing channels in that server includes the updated name

    Scenario: Non-owner cannot update a channel name
      Given a channel exists in a server owned by another user
      When the non-owner attempts to update the channel name
      Then the update is forbidden

    Scenario: Updating a missing channel reports that it does not exist
      When the user updates a channel that does not exist
      Then the user is told the channel does not exist

    Scenario: Server owner can add a server member
      Given the user already owns a server
      When the server owner adds another user as a member
      Then the server membership is created successfully

    Scenario: Server owner can delete a server
      Given the user already owns a server
      When the server owner deletes that server
      Then the delete succeeds
      And listing servers for that user returns no servers

    Scenario: Deleting a missing server reports that it does not exist
      When the user deletes a server that does not exist
      Then the user is told the server does not exist

    Scenario: Server owner can delete a channel
      Given a channel exists in the user's server
      When the server owner deletes that channel
      Then the delete succeeds
      And listing channels in that server returns no channels

    Scenario: Deleting a missing channel reports that it does not exist
      When the user deletes a channel that does not exist
      Then the user is told the channel does not exist

  Rule: Distinct named users enforce membership and ownership rules
    Scenario: Added server member can list the shared server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns a server
      And "Olivia" adds "Noah" to the server
      When "Noah" lists their servers
      Then the shared server is included in their server list

    Scenario: Non-member cannot list channels in a server they do not belong to
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns a server
      And a channel exists in "Olivia"'s server
      When "Noah" lists channels in that server
      Then listing channels is forbidden

    Scenario: Non-owner cannot add a server member
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns a server
      And "Olivia" adds "Noah" to the server
      When "Noah" tries to add a different user to that server
      Then the add-member action is forbidden

    Scenario: Non-owner cannot delete a server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns a server
      And "Olivia" adds "Noah" to the server
      When "Noah" deletes that server
      Then the delete is forbidden

    Scenario: Non-owner cannot delete a channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a channel exists in "Olivia"'s server
      And "Olivia" adds "Noah" to the server
      When "Noah" deletes that channel
      Then the delete is forbidden
