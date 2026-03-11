Feature: Friends, direct messaging, and safety controls
  As an authenticated user
  I want to manage friendships, direct conversations, and safety boundaries
  So that private communication remains intentional and protected

  Rule: Friend request lifecycle is explicit and durable
    Scenario: User can send and accept a friend request
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      When "Olivia" sends a friend request to "Noah"
      And "Noah" accepts the friend request from "Olivia"
      Then "Olivia" is included in the friend list for "Noah"
      And "Noah" is included in the friend list for "Olivia"

    Scenario: User can decline an incoming friend request
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" sent a friend request to "Noah"
      When "Noah" declines the friend request from "Olivia"
      Then "Olivia" is not included in the friend list for "Noah"
      And "Noah" is not included in the friend list for "Olivia"

    Scenario: User can cancel an outgoing friend request
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" sent a friend request to "Noah"
      When "Olivia" cancels the friend request to "Noah"
      Then "Noah" has no pending friend request from "Olivia"

    Scenario: Friend request notifications are emitted once per transition
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      When "Olivia" sends a friend request to "Noah"
      And "Noah" accepts the friend request from "Olivia"
      Then "Noah" receives one friend request notification from "Olivia"
      And "Olivia" receives one friend request accepted notification from "Noah"

  Rule: Direct messaging requires an active friendship
    Scenario: Friends can open and reuse a direct message thread
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" and "Noah" are friends
      When "Olivia" opens a direct message thread with "Noah"
      And "Olivia" opens a direct message thread with "Noah" again
      Then both thread openings resolve to the same direct message thread

    Scenario: Friends can exchange direct messages
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" and "Noah" are friends
      And a direct message thread exists between "Olivia" and "Noah"
      When "Olivia" sends a direct message to "Noah"
      Then listing direct messages between "Olivia" and "Noah" includes the new message

    Scenario: Non-friends cannot send direct messages
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      When "Olivia" sends a direct message to "Noah"
      Then direct messaging is denied because they are not friends

    Scenario: DM message search only returns messages visible to the requesting user
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a user named "Emma" exists
      And "Olivia" and "Noah" are friends
      And a direct message thread exists between "Olivia" and "Noah"
      And "Olivia" sent a direct message containing "alpha" to "Noah"
      When "Emma" searches direct messages with "Noah" for "alpha"
      Then direct message search is denied

  Rule: Blocking applies two-way restrictions and can be reverted
    Scenario: Blocking prevents friend actions and direct messages in both directions
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" and "Noah" are friends
      And a direct message thread exists between "Olivia" and "Noah"
      When "Olivia" blocks "Noah"
      Then "Noah" cannot send a friend request to "Olivia"
      And "Olivia" cannot send a friend request to "Noah"
      And "Noah" cannot send a direct message to "Olivia"
      And "Olivia" cannot send a direct message to "Noah"

    Scenario: Unblocking restores previous friendship relationship
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And "Olivia" and "Noah" are friends
      And "Olivia" blocked "Noah"
      When "Olivia" unblocks "Noah"
      Then "Olivia" is included in the friend list for "Noah"
      And "Noah" is included in the friend list for "Olivia"

  Rule: Shared-server context can bootstrap social connections
    Scenario: User can send a friend request to a member of a shared server
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And "Olivia" adds "Noah" to server "Test"
      When "Noah" sends a friend request to "Olivia" from server "Test"
      Then "Olivia" has a pending friend request from "Noah"
