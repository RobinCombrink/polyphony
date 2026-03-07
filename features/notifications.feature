Feature: Notifications
  As an authenticated user
  I want durable notifications and unread counters
  So that foreground and background clients stay consistent

  Rule: Message persistence is the authoritative trigger for notifications
    Background:
      Given an authenticated user exists

    Scenario: Persisted message increments unread count for other members
      Given a text channel exists in a shared server
      When another member posts a message in that channel
      Then unread count increments for eligible recipients
      And a notification outbox event is recorded per eligible recipient

    Scenario: Message author does not receive their own unread increment
      Given a text channel exists in a shared server
      When the authenticated user posts a message in that channel
      Then the author unread count is not incremented
      And no notification outbox event is recorded for the author

    Scenario: Failed message creation does not enqueue notifications
      Given a voice channel exists in the user's server
      When the user posts a message in that voice channel
      Then posting is denied because that channel does not support messaging
      And no notification outbox event is recorded

  Rule: Notification policy precedence controls unread increments
    Background:
      Given an authenticated user exists
      And the user has a server with a text channel

    Scenario: Muted server suppresses channel notification increments
      Given the user has muted that server
      When a new message is posted in that channel
      Then no unread-notification increment is recorded for that user

    Scenario: Temporarily muted channel suppresses increments until mute expires
      Given the user has temporarily muted that channel for 30 minutes
      When a new message is posted in that channel before mute expiry
      Then no unread-notification increment is recorded for that user
      When the temporary mute expires
      And a new message is posted in that channel
      Then the unread-notification increment is recorded for that user

  Rule: Websocket delivery mirrors durable unread updates for connected clients
    Background:
      Given an authenticated user exists
      And the user has a server with a text channel

    Scenario: Connected websocket recipient receives message-created notification event
      Given the user is connected to notifications websocket
      When another member posts a message in that channel
      Then the websocket stream includes a message-created notification for that channel

    Scenario: Websocket does not deliver notifications for unauthorized channels
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a text channel exists in "Olivia"'s server
      And "Noah" is connected to notifications websocket
      When "Olivia" posts a message in that channel
      Then "Noah" does not receive websocket notification events for that channel

  Rule: Aggregated unread counts are consistent across clients
    Background:
      Given an authenticated user exists

    Scenario: Unread counts exclude muted sources and include active channels
      Given the user belongs to two servers with text channels
      And one server is muted for that user
      And one channel in the unmuted server is active
      When new messages are posted in all channels
      Then the aggregated unread-notification count includes only unmuted active channels
      And desktop badge count matches the aggregated unread-notification count
      And mobile badge count matches the aggregated unread-notification count
