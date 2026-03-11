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
      Given the user already owns server "Test"
      When the user lists their servers
      Then the owned server is included in the server list

    Scenario: Authenticated user can create a server channel
      Given the user already owns server "Test"
      When the user creates a channel in server "Test"
      Then the server channel is created successfully

    Scenario: Authenticated user can list channels in server
      Given a channel exists in server "Test" for the authenticated user
      When the user lists channels in server "Test"
      Then the channel is included in the channel list

    Scenario: Server owner can update a channel name
      Given a channel exists in server "Test" for the authenticated user
      When the server owner updates the channel name
      Then listing channels in server "Test" includes the updated name

    Scenario: Non-owner cannot update a channel name
      Given a channel exists in a server owned by another user
      When the non-owner attempts to update the channel name
      Then the update is denied

    Scenario: Updating a missing channel reports that it does not exist
      When the user updates a channel that does not exist
      Then the action fails because the channel does not exist

    Scenario: Server owner can add a server member
      Given the user already owns server "Test"
      When the server owner adds another user as a member
      Then the server membership is created successfully

    Scenario: Server owner cannot add a server member with an invalid user identifier
      Given the user already owns server "Test"
      When the server owner adds a member with an invalid user identifier
      Then adding a member fails with invalid input

    Scenario: Server owner can delete a server
      Given the user already owns server "Test"
      When the server owner deletes server "Test"
      Then the delete succeeds
      And listing servers for the authenticated user returns no servers

    Scenario: Deleting a missing server reports that it does not exist
      When the user deletes a server that does not exist
      Then the action fails because the server does not exist

    Scenario: Server owner can delete a channel
      Given a channel exists in server "Test" for the authenticated user
      When the server owner deletes channel "general"
      Then the delete succeeds
      And listing channels in server "Test" returns no channels

    Scenario: Deleting a missing channel reports that it does not exist
      When the user deletes a channel that does not exist
      Then the action fails because the channel does not exist

  Rule: Distinct named users enforce membership and ownership rules
    Scenario: Added server member can list the shared server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns server "Test"
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" lists their servers
      Then the shared server is included in their server list

    Scenario: Non-member cannot list channels in a server they do not belong to
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns server "Test"
      And a channel exists in server "Test" owned by "Olivia"
      When "Noah" lists channels in server "Test"
      Then channel listing is denied

    Scenario: Non-owner cannot add a server member
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns server "Test"
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" tries to add a different user to server "Test"
      Then adding a member is denied

    Scenario: Non-owner cannot delete a server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns server "Test"
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" deletes server "Test"
      Then the delete is denied

    Scenario: Non-owner cannot delete a channel
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a channel exists in server "Test" owned by "Olivia"
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" deletes channel "general"
      Then the delete is denied

  Rule: Friend-only invite flow controls server invitations
    Scenario: Server owner can invite a friend to server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" and "Noah" are friends
      And "Olivia" owns server "Test"
      When "Olivia" invites friend "Noah" to server "Test"
      Then the server membership is created successfully

    Scenario: Server owner cannot invite a non-friend to server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" owns server "Test"
      When "Olivia" invites friend "Noah" to server "Test"
      Then inviting a friend is denied because they are not friends

