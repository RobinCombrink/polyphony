Feature: Voice sessions and live rooms
  Users can join voice sessions, connect to LiveKit, and query live room participants.

  Background:
    Given an authenticated user with a valid bearer token

  Scenario: Join voice session adds participant to listing
    Given the user created a server and channel
    When the user joins the channel voice session
    Then the response status is 201
    When the user lists channel voice sessions
    Then the response status is 200
    And the response contains exactly 1 voice participant
    And the participant subject equals the authenticated user subject

  Scenario: Leave voice session removes participant from listing
    Given the user created a server and channel
    And the user joined the channel voice session
    When the user leaves the channel voice session
    Then the response status is 204
    When the user lists channel voice sessions
    Then the response status is 200
    And the response contains 0 voice participants

  Scenario: Joining missing channel voice session returns not found
    When the user joins a missing channel voice session
    Then the response status is 404

  Scenario: Connect voice session returns LiveKit credentials
    Given the user created a server and channel
    When the user connects to channel voice
    Then the response status is 200
    And the payload channel_id equals the created channel id
    And the payload participant_subject equals the authenticated user subject
    And the payload livekit_url equals ws://127.0.0.1:7880
    And the payload access_token is present
    And listing voice sessions contains that participant

  Scenario: Connecting voice in missing channel returns not found
    When the user connects voice in a missing channel
    Then the response status is 404

  Scenario: Listing live room participants for missing channel returns not found
    When the user lists live room participants for a missing channel
    Then the response status is 404

  Scenario: Listing live room participants for existing channel returns room payload
    Given the user created a server and channel
    When the user lists live room participants for that channel
    Then the response status is 200
    And the payload channel_id equals the created channel id
    And the payload participant_subjects is an array
