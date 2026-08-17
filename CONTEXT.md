# Polyphony

Real-time communication: people join Servers, talk in Channels, message each other directly,
and hold voice conversations. This glossary fixes the words for those concepts. It defines
what things ARE; how they are built is not its business.

## Membership and identity

**User**:
A person with an account. Identity is issued by Auth0; the domain holds the User record.
_Avoid_: account, member, profile

**Display Name**:
The name a User is shown as. Non-empty after trimming and length-bounded, so it is a value
object rather than a bare string.
_Avoid_: username, nickname, handle

**Server**:
A community a User joins, owned by exactly one User. The word is reserved for this concept.
The Rust service is **the backend** (or `backend-api`) and is never called "the server".
_Avoid_: guild, space, community, workspace — and never the backend service

**Membership**:
The fact that a User belongs to a Server. It is the relationship itself, carrying no role or
permission of its own.
_Avoid_: join, subscription, enrollment

**Friend Request**:
One User's proposal of friendship to another, in exactly one of four states: pending,
accepted, declined, cancelled. Declining and cancelling are silent — the other party is never
told.
_Avoid_: invite, friend invite

**Friendship**:
A settled mutual relationship between two Users. Distinct from the Friend Request that
produced it, and unordered — neither User is the owner.
_Avoid_: friend, contact, connection

## Conversation

**Channel**:
A named conversation belonging to a Server, in exactly one of two kinds — **Text Channel** or
**Voice Channel**. Every Channel belongs to a Server; there is no Server-less Channel.
_Avoid_: room, chat, thread

**Message**:
Something a User said in a Text Channel. Distinct from a Direct Message: a Message always
belongs to a Server through its Channel.
_Avoid_: post, chat message

**Direct Message Thread**:
A private conversation between Users, belonging to no Server. It is not a Channel and does not
become one.
_Avoid_: DM channel, private channel, group chat

**Direct Message**:
Something a User said in a Direct Message Thread. A separate concept from Message — the two
share behaviour such as reactions and pinning, but neither is a kind of the other.
_Avoid_: private message, DM (in prose; acceptable in UI)

**Reaction**:
A User's emoji response attached to a Message.
_Avoid_: emoji, vote

**Pinned Message**:
A Message singled out for prominence within its conversation.
_Avoid_: starred, bookmarked, saved

## Voice

**Presence**:
Who is currently in a Voice Channel. **LiveKit owns this, not the domain.** There is
deliberately no persisted voice-session entity, and one should not be reintroduced; the
backend issues short-lived tokens and performs privileged admin operations, and never proxies
media.
_Avoid_: online status, participation, voice session

**Voice Mute**:
A User prevented from transmitting audio. Server-authoritative — the Server decides, not the
client. Never written as bare "mute".
_Avoid_: mute, silenced, deafened

## Notification

**Notification Mute**:
Alerts silenced for a scope, optionally until a time. Applies at global, Server or Channel
scope. A wholly separate concept from Voice Mute; never written as bare "mute".
_Avoid_: mute, snooze, do not disturb

**Notification Preference**:
How much a User wants to hear from a scope: all messages, only mentions, or none. Resolved
against global, Server and Channel scope by one policy resolver.
_Avoid_: notification setting, alert level, notification level

## Words with no referent here

**Session** is not a domain term. It names only the endpoint that issues a media token
(`channels/{id}/session`), and carries no domain meaning; see Presence.

**Server** never means the backend service. See Server above.

**Mute**, unqualified, means nothing. See Voice Mute and Notification Mute.
