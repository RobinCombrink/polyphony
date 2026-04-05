use backend_domain::{Channel, Membership, Message, Server};
use utoipa::openapi::{
    Components,
    security::{HttpAuthScheme, HttpBuilder, SecurityScheme},
};
use utoipa::{Modify, OpenApi};

use crate::dto::ApiErrorResponse;
use crate::dto::{
    AddServerMemberRequest, BlockRelationshipResponse, CreateChannelRequest, CreateMessageRequest,
    CreateServerRequest, CreateSessionRequest, DirectMessageResponse, DirectMessageThreadResponse,
    FriendRequestResponse, FriendSummaryResponse, HealthResponse, MeResponse,
    MuteChannelNotificationsRequest, NotificationChannelPreferenceResponse,
    NotificationGlobalPreferenceResponse, NotificationServerPreferenceResponse,
    NotificationUnreadCountResponse, SendDirectMessageRequest, UpdateChannelRequest,
    UpdateMeRequest, UpdateMessageRequest, UpdateNotificationChannelPreferenceRequest,
    UpdateNotificationGlobalPreferenceRequest, UpdateNotificationServerPreferenceRequest,
    UpdateServerRequest, UserLookupResponse, VoiceConnectResponse,
};

#[derive(OpenApi)]
#[openapi(
    components(schemas(
        HealthResponse,
        MeResponse,
        UserLookupResponse,
        UpdateMeRequest,
        Server,
        Membership,
        Channel,
        Message,
        VoiceConnectResponse,
        AddServerMemberRequest,
        CreateServerRequest,
        CreateChannelRequest,
        CreateSessionRequest,
        UpdateChannelRequest,
        UpdateServerRequest,
        CreateMessageRequest,
        UpdateMessageRequest,
        ApiErrorResponse,
        MuteChannelNotificationsRequest,
        NotificationGlobalPreferenceResponse,
        NotificationServerPreferenceResponse,
        NotificationChannelPreferenceResponse,
        NotificationUnreadCountResponse,
        UpdateNotificationGlobalPreferenceRequest,
        UpdateNotificationServerPreferenceRequest,
        UpdateNotificationChannelPreferenceRequest,
        FriendSummaryResponse,
        FriendRequestResponse,
        BlockRelationshipResponse,
        DirectMessageThreadResponse,
        DirectMessageResponse,
        SendDirectMessageRequest,
    )),
    modifiers(&ApiSecurityAddon),
    tags(
        (name = "Health", description = "Health check endpoints"),
        (name = "Identity", description = "Authenticated user identity"),
        (name = "Users", description = "User lookup"),
        (name = "Servers", description = "Server management"),
        (name = "Channels", description = "Channel management"),
        (name = "Messages", description = "Channel messages"),
        (name = "Voice", description = "Voice session management"),
        (name = "Notifications", description = "Notification preferences and unread counts"),
        (name = "Friends", description = "Friend relationships and requests"),
        (name = "Blocks", description = "User block list management"),
        (name = "Direct Messages", description = "Direct messaging between users"),
    )
)]
pub(crate) struct ApiDocumentation;

pub(crate) struct ApiSecurityAddon;

impl Modify for ApiSecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.get_or_insert_with(Components::new);

        components.add_security_scheme(
            "bearer_auth",
            SecurityScheme::Http(
                HttpBuilder::new()
                    .scheme(HttpAuthScheme::Bearer)
                    .bearer_format("JWT")
                    .build(),
            ),
        );
    }
}
