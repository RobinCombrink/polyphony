Feature: Notifications
  As an authenticated user
  I want durable notifications and unread counters
  So that foreground and background clients stay consistent

  Rule: Message persistence is the authoritative trigger for notifications
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a text channel exists in "Olivia"'s server
      And "Olivia" adds "Noah" to the server

    Scenario: Persisted message increments unread count for other members
      When "Olivia" posts a message in that channel
      Then unread count increments for "Noah" in that channel
      And a notification outbox event is recorded for "Noah"

    Scenario: Message author does not receive their own unread increment
      When "Olivia" posts a message in that channel
      Then unread count for "Olivia" in that channel is zero
      And no notification outbox event is recorded for "Olivia"

    Scenario: Failed message creation does not enqueue notifications
      Given a voice channel exists in "Olivia"'s server
      When "Olivia" posts a message in that channel
      Then posting is denied because that channel does not support messaging
      And no notification outbox event is recorded for "Noah"

  Rule: Websocket delivery mirrors durable unread updates for connected clients
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a text channel exists in "Olivia"'s server

    Scenario: Connected websocket recipient receives message-created notification event
      Given "Olivia" adds "Noah" to the server
      And "Noah" is connected to notifications websocket
      When "Olivia" posts a message in that channel
      Then "Noah" receives a message-created websocket notification for that channel

    Scenario: Websocket does not deliver notifications for unauthorized channels
      Given "Noah" is connected to notifications websocket
      When "Olivia" posts a message in that channel
      Then "Noah" does not receive websocket notification events for that channel

  Rule: Unread count aggregation and mark-read lifecycle stay consistent
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a text channel named "engineering" exists in "Olivia"'s server
      And a text channel named "product" exists in "Olivia"'s server
      And "Olivia" adds "Noah" to the server

    Scenario: Aggregated unread count includes all unread channels for the recipient
      When "Olivia" posts a message in channel "engineering"
      And "Olivia" posts a message in channel "product"
      Then "Noah" sees total unread notification count of 2

    Scenario: Marking one channel as read only clears that channel unread count
      When "Olivia" posts a message in channel "engineering"
      And "Olivia" posts a message in channel "product"
      And "Noah" marks channel "engineering" notifications as read
      Then unread count for "Noah" in channel "engineering" is zero
      And "Noah" sees total unread notification count of 1
