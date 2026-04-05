use axum::{Json, http::StatusCode, response::IntoResponse};
use backend_storage::{
    BlockUserResult, MutationResult, OpenOrGetDirectMessageThreadResult, PinMessageResult,
    SendDirectMessageResult, ToggleReactionResult, UnpinMessageResult, UpdateFriendRequestResult,
};

use crate::dto::ApiErrorResponse;
use crate::dto::{DirectMessageResponse, DirectMessageThreadResponse, FriendRequestResponse};

pub(crate) struct UpdatedResponse(pub MutationResult);

impl IntoResponse for UpdatedResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            MutationResult::Updated => StatusCode::NO_CONTENT.into_response(),
            MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
            MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
            MutationResult::Deleted => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }
}

pub(crate) struct DeletedResponse(pub MutationResult);

impl IntoResponse for DeletedResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            MutationResult::Deleted => StatusCode::NO_CONTENT.into_response(),
            MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
            MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
            MutationResult::Updated => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }
}

pub(crate) struct UpdateFriendRequestResponse(pub UpdateFriendRequestResult);

impl IntoResponse for UpdateFriendRequestResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            UpdateFriendRequestResult::Updated(friend_request) => (
                StatusCode::OK,
                Json(FriendRequestResponse::from(friend_request)),
            )
                .into_response(),
            UpdateFriendRequestResult::Forbidden => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
            )
                .into_response(),
            UpdateFriendRequestResult::NotFound => (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new(
                    "NOT_FOUND",
                    "friend request was not found",
                )),
            )
                .into_response(),
            UpdateFriendRequestResult::InvalidState => (
                StatusCode::CONFLICT,
                Json(ApiErrorResponse::new(
                    "INVALID_STATE",
                    "friend request transition is invalid",
                )),
            )
                .into_response(),
        }
    }
}

pub(crate) struct BlockUserResponse(pub BlockUserResult);

impl IntoResponse for BlockUserResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            BlockUserResult::Created(_) => StatusCode::CREATED.into_response(),
            BlockUserResult::AlreadyBlocked => StatusCode::OK.into_response(),
            BlockUserResult::Forbidden => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
            )
                .into_response(),
            BlockUserResult::NotFound => (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new(
                    "NOT_FOUND",
                    "target user was not found",
                )),
            )
                .into_response(),
        }
    }
}

pub(crate) struct OpenOrGetDmThreadResponse(pub OpenOrGetDirectMessageThreadResult);

impl IntoResponse for OpenOrGetDmThreadResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            OpenOrGetDirectMessageThreadResult::Opened(thread) => (
                StatusCode::OK,
                Json(DirectMessageThreadResponse::from(thread)),
            )
                .into_response(),
            OpenOrGetDirectMessageThreadResult::Blocked => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new(
                    "USERS_BLOCKED",
                    "cannot open dm thread due to blocked relationship",
                )),
            )
                .into_response(),
            OpenOrGetDirectMessageThreadResult::Forbidden => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
            )
                .into_response(),
            OpenOrGetDirectMessageThreadResult::NotFound => (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new(
                    "NOT_FOUND",
                    "target user was not found",
                )),
            )
                .into_response(),
        }
    }
}

pub(crate) struct SendDirectMessageResponse(pub SendDirectMessageResult);

impl IntoResponse for SendDirectMessageResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            SendDirectMessageResult::Created(dm) => {
                (StatusCode::CREATED, Json(DirectMessageResponse::from(dm))).into_response()
            }
            SendDirectMessageResult::Blocked => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new(
                    "USERS_BLOCKED",
                    "cannot send dm due to blocked relationship",
                )),
            )
                .into_response(),
            SendDirectMessageResult::Forbidden => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
            )
                .into_response(),
            SendDirectMessageResult::NotFound => (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new(
                    "NOT_FOUND",
                    "dm thread was not found",
                )),
            )
                .into_response(),
        }
    }
}

pub(crate) struct ToggleReactionResponse(pub ToggleReactionResult);

impl IntoResponse for ToggleReactionResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            ToggleReactionResult::Added | ToggleReactionResult::Removed => {
                StatusCode::OK.into_response()
            }
            ToggleReactionResult::MessageNotFound => StatusCode::NOT_FOUND.into_response(),
        }
    }
}

pub(crate) struct PinMessageResponse(pub PinMessageResult);
impl IntoResponse for PinMessageResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            PinMessageResult::Pinned => StatusCode::OK.into_response(),
            PinMessageResult::AlreadyPinned => StatusCode::CONFLICT.into_response(),
            PinMessageResult::MessageNotFound => StatusCode::NOT_FOUND.into_response(),
        }
    }
}

pub(crate) struct UnpinMessageResponse(pub UnpinMessageResult);

impl IntoResponse for UnpinMessageResponse {
    fn into_response(self) -> axum::response::Response {
        match self.0 {
            UnpinMessageResult::Unpinned => StatusCode::OK.into_response(),
            UnpinMessageResult::NotPinned => StatusCode::NOT_FOUND.into_response(),
        }
    }
}
