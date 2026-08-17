# LiveKit owns presence, and the backend only issues session tokens

Status: accepted (2026-08-17, recorded from the decision made when `voice_session` was removed)

LiveKit is the source of truth for who is connected to a Channel. The backend holds no
presence state: its whole job is issuing short-lived LiveKit access tokens through one
`channels/{id}/session` endpoint, whose session-type parameter distinguishes text from voice,
plus privileged admin operations. It never proxies media. Real-time text travels over the
LiveKit data channel; historical messages come from REST and Postgres.

This supersedes an earlier design in which text and voice were fully separate flows and the
backend tracked voice sessions in a `voice_session` entity. That entity was deliberately
removed, and its absence is the point: a backend presence table is the obvious thing to add
and would be wrong.

## Considered options

- **A backend `voice_session` entity, written on connect and disconnect.** The shape most
  people reach for, and the one that was actually built first. It cannot be correct: LiveKit
  already holds the authoritative connection state, so any backend copy is a cache that
  disagrees the moment a client drops without a clean disconnect. Two sources of truth for one
  fact, with the less-informed one queried.
- **A session endpoint per session type.** Rejected because the two differ only by a parameter
  in the token they mint. Splitting them doubles the surface that has to stay in step and
  makes a third session type a third endpoint rather than a third parameter value.

## Consequences

- Presence questions are answered by querying LiveKit, never by reading a backend table.
- A new session type extends the session-type parameter on the existing endpoint; it does not
  add an endpoint.
- The backend cannot answer "who is in this Channel" from its own storage, and any feature
  needing that must go to LiveKit — accepted deliberately as the cost of one source of truth.
