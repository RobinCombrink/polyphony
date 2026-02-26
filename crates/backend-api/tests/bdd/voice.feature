Feature: Voice connect
  Users request LiveKit credentials for direct client-to-LiveKit connection.

  Background:
    Given an authenticated user with a valid bearer token

  Scenario: Connect voice session returns LiveKit credentials
    Given the user created a server and channel
    When the user connects to channel voice
    Then the response status is 200
    And the payload channel_id equals the created channel id
    And the payload participant_subject equals the authenticated user subject
    And the payload livekit_url equals ws://127.0.0.1:7880
    And the payload access_token is present

  Scenario: Connecting voice in missing channel returns not found
    When the user connects voice in a missing channel
    Then the response status is 404
