Feature: Notifications
  As an authenticated user
  I want durable notifications and unread counters
  So that foreground and background clients stay consistent

  Rule: Message persistence is the authoritative trigger for notifications
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "general" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"

    Scenario: Persisted message increments unread count for other members
      When "Olivia" posts a message in channel "general"
      Then unread count increments for "Noah" in channel "general"
      And a notification outbox event is recorded for "Noah"

    Scenario: Message author does not receive their own unread increment
      When "Olivia" posts a message in channel "general"
      Then unread count for "Olivia" in channel "general" is zero
      And no notification outbox event is recorded for "Olivia"

    Scenario: Failed message creation does not enqueue notifications
      Given a voice channel named "voice-alerts" exists in server "Test" created by "Olivia"
      When "Olivia" posts a message in channel "voice-alerts"
      Then posting is denied because channel "voice-alerts" does not support messaging
      And no notification outbox event is recorded for "Noah"

  Rule: Live message delivery follows category preferences for connected authorized recipients
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "general" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"
      And "Noah" is subscribed to live notifications

    Scenario: Connected recipient receives message-created notification event
      When "Olivia" posts a message in channel "general"
      Then "Noah" receives a message-created live notification for channel "general"

    Scenario: Connected recipient receives mentioned notification event
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" receives a mentioned live notification for channel "general"

    Scenario: Connected recipient receives unread message notification event
      Given "Noah" has all-messages channel default notifications
      When "Olivia" posts a plain message in channel "general"
      Then "Noah" receives an unread-message live notification for channel "general"

    Scenario: Connected recipient with all-messages default receives mentioned notification event
      Given "Noah" has all-messages channel default notifications
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" receives a mentioned live notification for channel "general"

    Scenario: Connected recipient with only-mentions default does not receive unread message notification event
      Given "Noah" has only-mentions channel default notifications
      When "Olivia" posts a plain message in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

    Scenario: Connected recipient with only-mentions default receives mentioned notification event
      Given "Noah" has only-mentions channel default notifications
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" receives a mentioned live notification for channel "general"

    Scenario: Connected recipient with none default does not receive unread message notification event
      Given "Noah" has none channel default notifications
      When "Olivia" posts a plain message in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

    Scenario: Connected recipient with none default does not receive mentioned notification event
      Given "Noah" has none channel default notifications
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

  Rule: Live message delivery respects mute precedence for connected authorized recipients
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "general" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"
      And "Noah" has all-messages channel default notifications
      And "Noah" is subscribed to live notifications

    Scenario: Globally muted recipient does not receive mentioned live notification event
      Given "Noah" has globally muted notifications
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

    Scenario: Globally muted recipient does not receive unread message live notification event
      Given "Noah" has globally muted notifications
      When "Olivia" posts a plain message in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

    Scenario: Muted server recipient does not receive mentioned live notification event
      Given "Noah" has muted server "Test"
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

    Scenario: Muted server recipient does not receive unread message live notification event
      Given "Noah" has muted server "Test"
      When "Olivia" posts a plain message in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

    Scenario: Temporarily muted channel recipient does not receive unread message live notification event until unmuted
      Given "Noah" has temporarily muted channel "general" for 30 minutes
      When "Olivia" posts a plain message in channel "general"
      Then "Noah" does not receive live notification events for channel "general"
      When the temporary mute expires for "Noah" in channel "general"
      And "Olivia" posts a plain message in channel "general"
      Then "Noah" receives an unread-message live notification for channel "general"

  Rule: Live message delivery recovers by category after temporary channel mute expires
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "general" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"
      And "Noah" is subscribed to live notifications

    Scenario: Temporarily muted channel recipient does not receive mentioned live notification event until unmuted
      Given "Noah" has only-mentions channel default notifications
      And "Noah" has temporarily muted channel "general" for 30 minutes
      When "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" does not receive live notification events for channel "general"
      When the temporary mute expires for "Noah" in channel "general"
      And "Olivia" posts a message mentioning "Noah" in channel "general"
      Then "Noah" receives a mentioned live notification for channel "general"

  Rule: Live delivery only targets authorized recipients
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "general" exists in server "Test" created by "Olivia"

    Scenario: Live delivery does not include unauthorized channels
      Given "Noah" is subscribed to live notifications
      When "Olivia" posts a message in channel "general"
      Then "Noah" does not receive live notification events for channel "general"

  Rule: Live friend request delivery reaches connected recipients
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists

    Scenario: Connected addressee receives friend request received live notification event
      Given "Noah" is subscribed to live notifications
      When "Olivia" sends a friend request to "Noah"
      Then "Noah" receives a friend-request-received live notification from "Olivia"

    Scenario: Connected requester receives friend request accepted live notification event
      Given "Olivia" is subscribed to live notifications
      And "Olivia" sent a friend request to "Noah"
      When "Noah" accepts the friend request from "Olivia"
      Then "Olivia" receives a friend-request-accepted live notification from "Noah"

  Rule: Live voice events are delivered to other members and not echoed to the joining user
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "general" exists in server "Test" created by "Olivia"
      And a voice channel named "voice-lobby" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"

    Scenario: Connected recipient receives friend joined voice notification event
      Given "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

    Scenario: Joining user does not receive their own friend joined voice notification event
      Given "Olivia" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Olivia" does not receive live notification events for channel "voice-lobby"

    Scenario: Connected recipient with all-messages default receives friend joined voice notification event
      Given "Noah" has all-messages channel default notifications
      And "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

    Scenario: Connected recipient with only-mentions default receives friend joined voice notification event
      Given "Noah" has only-mentions channel default notifications
      And "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

    Scenario: Connected recipient with none default receives friend joined voice notification event
      Given "Noah" has none channel default notifications
      And "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

    Scenario: Globally muted recipient still receives friend joined voice notification event
      Given "Noah" has globally muted notifications
      And "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

    Scenario: Muted server recipient still receives friend joined voice notification event
      Given "Noah" has muted server "Test"
      And "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

    Scenario: Temporarily muted voice channel recipient still receives friend joined voice notification event
      Given "Noah" has temporarily muted channel "voice-lobby" for 30 minutes
      And "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" receives a friend-joined-voice live notification for channel "voice-lobby" from "Olivia"

  Rule: Live voice events only target authorized server members
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a voice channel named "voice-lobby" exists in server "Test" created by "Olivia"

    Scenario: Unauthorized recipient does not receive friend joined voice notification event
      Given "Noah" is subscribed to live notifications
      When "Olivia" connects to voice for channel "voice-lobby"
      Then "Noah" does not receive live notification events for channel "voice-lobby"

  Rule: Unread count aggregation and mark-read lifecycle stay consistent
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "engineering" exists in server "Test" created by "Olivia"
      And a text channel named "product" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"

    Scenario: Aggregated unread count includes all unread channels for the recipient
      When "Olivia" posts a message in channel "engineering"
      And "Olivia" posts a message in channel "product"
      Then "Noah" sees total unread notification count of 2

    Scenario: Marking one channel as read only clears that named channel unread count
      When "Olivia" posts a message in channel "engineering"
      And "Olivia" posts a message in channel "product"
      And "Noah" marks channel "engineering" notifications as read
      Then unread count for "Noah" in channel "engineering" is zero
      And "Noah" sees total unread notification count of 1

  Rule: Notification policy precedence controls unread increments
    Background:
      Given a user named "Olivia" exists
      And a user named "Noah" exists
      And a server named "Test" owned by "Olivia" exists
      And a text channel named "engineering" exists in server "Test" created by "Olivia"
      And "Olivia" adds "Noah" to server "Test"

    Scenario: Muted server suppresses channel notification increments
      Given "Noah" has muted server "Test"
      When "Olivia" posts a message in channel "engineering"
      Then unread count for "Noah" in channel "engineering" is zero
      And no notification outbox event is recorded for "Noah" for the last message
      And "Noah" sees total unread notification count of 0

    Scenario: Temporarily muted channel suppresses increments until mute expires
      Given "Noah" has temporarily muted channel "engineering" for 30 minutes
      When "Olivia" posts a message in channel "engineering"
      Then unread count for "Noah" in channel "engineering" is zero
      And no notification outbox event is recorded for "Noah" for the last message
      When the temporary mute expires for "Noah" in channel "engineering"
      And "Olivia" posts a message in channel "engineering"
      Then unread count increments for "Noah" in channel "engineering"
      And "Noah" sees total unread notification count of 1

    Scenario: Global mute suppresses notifications until the user unmutes globally
      Given "Noah" has globally muted notifications
      When "Olivia" posts a message in channel "engineering"
      Then unread count for "Noah" in channel "engineering" is zero
      And no notification outbox event is recorded for "Noah" for the last message
      And "Noah" sees total unread notification count of 0
      When "Noah" globally unmutes notifications
      And "Olivia" posts a message in channel "engineering"
      Then unread count increments for "Noah" in channel "engineering"
      And "Noah" sees total unread notification count of 1

    Scenario: Server mute still suppresses notifications after global mute is lifted
      Given "Noah" has globally muted notifications
      And "Noah" has muted server "Test"
      When "Olivia" posts a message in channel "engineering"
      Then unread count for "Noah" in channel "engineering" is zero
      And no notification outbox event is recorded for "Noah" for the last message
      When "Noah" globally unmutes notifications
      And "Olivia" posts a message in channel "engineering"
      Then unread count for "Noah" in channel "engineering" is zero
      And no notification outbox event is recorded for "Noah" for the last message
      When "Noah" unmutes server "Test"
      And "Olivia" posts a message in channel "engineering"
      Then unread count increments for "Noah" in channel "engineering"
      And "Noah" sees total unread notification count of 1

    Scenario: Preference APIs reflect global, server, and channel mute state
      Given "Noah" has globally muted notifications
      And "Noah" has muted server "Test"
      And "Noah" has temporarily muted channel "engineering" for 30 minutes
      Then "Noah" sees global notification preference mute state is muted
      And "Noah" sees server notification preference mute state is muted
      And "Noah" sees channel "engineering" notification preference mute state is muted
      And "Noah" sees channel "engineering" mute expiry timestamp is present
