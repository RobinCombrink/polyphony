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

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::routes::health::health,
        crate::routes::me::me,
        crate::routes::servers::create_server,
        crate::routes::servers::list_servers,
        crate::routes::servers::create_channel,
        crate::routes::servers::list_channels,
        crate::routes::messages::create::create_message,
        crate::routes::messages::update::update_message,
        crate::routes::messages::delete::delete_message,
        crate::routes::messages::list::list_messages
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
