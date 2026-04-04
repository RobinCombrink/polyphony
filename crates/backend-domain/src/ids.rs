use std::fmt::{Display, Formatter};

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

macro_rules! define_uuid_id {
    ($name:ident) => {
        #[repr(transparent)]
        #[derive(
            Debug,
            Clone,
            Copy,
            PartialEq,
            Eq,
            PartialOrd,
            Ord,
            Hash,
            Serialize,
            Deserialize,
            ToSchema,
        )]
        #[serde(transparent)]
        pub struct $name(Uuid);

        impl $name {
            pub fn as_uuid(&self) -> &Uuid {
                &self.0
            }
        }

        impl Display for $name {
            fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
                self.0.fmt(f)
            }
        }

        impl From<Uuid> for $name {
            fn from(value: Uuid) -> Self {
                Self(value)
            }
        }

        impl From<$name> for Uuid {
            fn from(value: $name) -> Self {
                value.0
            }
        }
    };
}

#[repr(transparent)]
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, ToSchema)]
#[serde(transparent)]
pub struct ExternalReference(String);

impl ExternalReference {
    pub fn new(value: String) -> Self {
        Self(value)
    }

    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }
}

impl Display for ExternalReference {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

impl AsRef<str> for ExternalReference {
    fn as_ref(&self) -> &str {
        self.0.as_str()
    }
}

impl From<String> for ExternalReference {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl From<&str> for ExternalReference {
    fn from(value: &str) -> Self {
        Self(value.to_owned())
    }
}

impl From<ExternalReference> for String {
    fn from(value: ExternalReference) -> Self {
        value.0
    }
}

define_uuid_id!(UserId);
define_uuid_id!(ServerId);
define_uuid_id!(ChannelId);
define_uuid_id!(MessageId);
define_uuid_id!(FriendRequestId);
define_uuid_id!(FriendshipId);
define_uuid_id!(BlockRelationshipId);
define_uuid_id!(DirectMessageThreadId);
define_uuid_id!(DirectMessageId);
define_uuid_id!(ReactionId);
define_uuid_id!(PinnedMessageId);

#[repr(transparent)]
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, ToSchema)]
#[serde(transparent)]
pub struct EmoteId(String);

impl EmoteId {
    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }
}

impl Display for EmoteId {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

impl AsRef<str> for EmoteId {
    fn as_ref(&self) -> &str {
        self.0.as_str()
    }
}

impl From<String> for EmoteId {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl From<&str> for EmoteId {
    fn from(value: &str) -> Self {
        Self(value.to_owned())
    }
}

impl From<EmoteId> for String {
    fn from(value: EmoteId) -> Self {
        value.0
    }
}
