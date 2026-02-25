use backend_domain::{Channel, Message, Server};
use utoipa::openapi::{
    Components,
    security::{HttpAuthScheme, HttpBuilder, SecurityScheme},
};
use utoipa::{Modify, OpenApi};

use crate::dto::{
    CreateChannelRequest, CreateMessageRequest, CreateServerRequest, HealthResponse, MeResponse,
    UpdateMessageRequest,
};
use crate::routes::{
    health::health,
    me::me,
    messages::{create_message, delete_message, list_messages, update_message},
    servers::{create_channel, create_server, list_channels, list_servers},
};

#[derive(OpenApi)]
#[openapi(
    paths(
        health,
        me,
        create_server,
        list_servers,
        create_channel,
        list_channels,
        create_message,
        update_message,
        delete_message,
        list_messages
    ),
    components(schemas(
        HealthResponse,
        MeResponse,
        Server,
        Channel,
        Message,
        CreateServerRequest,
        CreateChannelRequest,
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
