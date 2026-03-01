use backend_domain::{Channel, Membership, Message, Server, VoiceSession};
use utoipa::openapi::{
    Components,
    security::{HttpAuthScheme, HttpBuilder, SecurityScheme},
};
use utoipa::{Modify, OpenApi};

use crate::dto::{
    AddServerMemberRequest, CreateChannelRequest, CreateMessageRequest, CreateServerRequest,
    HealthResponse, MeResponse, SetVoiceSessionMuteRequest, UpdateChannelRequest, UpdateMeRequest,
    UpdateMessageRequest, UserLookupResponse, VoiceConnectResponse,
};

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::routes::health::health,
        crate::routes::me::me,
        crate::routes::me::update_me,
        crate::routes::users::get_user_by_id,
        crate::routes::servers::create_server,
        crate::routes::servers::list_servers,
        crate::routes::servers::list_server_members,
        crate::routes::servers::add_server_member,
        crate::routes::servers::delete_server,
        crate::routes::servers::create_channel,
        crate::routes::servers::update_channel,
        crate::routes::servers::delete_channel,
        crate::routes::servers::list_channels,
        crate::routes::messages::create::create_message,
        crate::routes::messages::update::update_message,
        crate::routes::messages::delete::delete_message,
        crate::routes::messages::list::list_messages,
        crate::routes::voice::connect_voice_session,
        crate::routes::voice::update_self_mute_state,
        crate::routes::voice::list_voice_sessions
    ),
    components(schemas(
        HealthResponse,
        MeResponse,
        UserLookupResponse,
        UpdateMeRequest,
        Server,
        Membership,
        Channel,
        Message,
        VoiceSession,
        VoiceConnectResponse,
        SetVoiceSessionMuteRequest,
        AddServerMemberRequest,
        CreateServerRequest,
        CreateChannelRequest,
        UpdateChannelRequest,
        CreateMessageRequest,
        UpdateMessageRequest
    )),
    modifiers(&ApiSecurityAddon),
    tags((name = "backend-api", description = "Polyphony backend API"))
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
