use std::net::IpAddr;

use axum::{Json, extract::Query, http::StatusCode, response::IntoResponse};
use serde::Deserialize;
use url::Url;

use crate::dto::LinkPreviewResponse;

const MAX_RESPONSE_BYTES: usize = 256 * 1024;
const REQUEST_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(3);
const MAX_REDIRECTS: usize = 3;

#[derive(Debug, Deserialize, utoipa::IntoParams)]
pub(crate) struct LinkPreviewQuery {
    url: String,
}

#[utoipa::path(
    get,
    path = "/api/v1/link-preview",
    params(LinkPreviewQuery),
    responses(
        (status = 200, description = "Link preview metadata", body = LinkPreviewResponse),
        (status = 400, description = "Invalid or disallowed URL"),
        (status = 502, description = "Failed to fetch link metadata")
    ),
    security(("bearer_auth" = [])),
    tag = "Link Preview"
)]
pub(crate) async fn link_preview(
    _authenticated_user: crate::auth::AuthenticatedUser,
    Query(query): Query<LinkPreviewQuery>,
) -> impl IntoResponse {
    let parsed_url = match Url::parse(query.url.trim()) {
        Ok(url) => url,
        Err(_) => return StatusCode::BAD_REQUEST.into_response(),
    };

    if parsed_url.scheme() != "http" && parsed_url.scheme() != "https" {
        return StatusCode::BAD_REQUEST.into_response();
    }

    let Some(host) = parsed_url.host_str() else {
        return StatusCode::BAD_REQUEST.into_response();
    };

    if is_private_or_loopback_host(host) {
        return StatusCode::BAD_REQUEST.into_response();
    }

    let client = match reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .redirect(reqwest::redirect::Policy::limited(MAX_REDIRECTS))
        .build()
    {
        Ok(client) => client,
        Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    };

    let response = match client.get(parsed_url.as_str()).send().await {
        Ok(response) => response,
        Err(_) => return StatusCode::BAD_GATEWAY.into_response(),
    };

    if !response.status().is_success() {
        return StatusCode::BAD_GATEWAY.into_response();
    }

    let final_url_host = response.url().host_str().unwrap_or("");
    if is_private_or_loopback_host(final_url_host) {
        return StatusCode::BAD_REQUEST.into_response();
    }

    let body_bytes = match response.bytes().await {
        Ok(bytes) if bytes.len() <= MAX_RESPONSE_BYTES => bytes,
        Ok(_) => return StatusCode::BAD_GATEWAY.into_response(),
        Err(_) => return StatusCode::BAD_GATEWAY.into_response(),
    };

    let body_text = String::from_utf8_lossy(&body_bytes);
    let metadata = extract_metadata(&body_text);

    let preview = LinkPreviewResponse {
        url: query.url,
        title: metadata.title,
        description: metadata.description,
        image_url: metadata.image_url,
    };

    (StatusCode::OK, Json(preview)).into_response()
}

struct PageMetadata {
    title: Option<String>,
    description: Option<String>,
    image_url: Option<String>,
}

fn extract_metadata(html: &str) -> PageMetadata {
    let document = scraper::Html::parse_document(html);
    let meta_selector =
        scraper::Selector::parse("meta").unwrap_or_else(|_| scraper::Selector::parse("*").unwrap());
    let title_selector = scraper::Selector::parse("title")
        .unwrap_or_else(|_| scraper::Selector::parse("*").unwrap());

    let mut og_title: Option<String> = None;
    let mut og_description: Option<String> = None;
    let mut og_image: Option<String> = None;
    let mut meta_description: Option<String> = None;

    for element in document.select(&meta_selector) {
        let property = element.value().attr("property").unwrap_or("");
        let name = element.value().attr("name").unwrap_or("");
        let content = element.value().attr("content").unwrap_or("").trim();

        if content.is_empty() {
            continue;
        }

        match property {
            "og:title" => og_title = Some(content.to_owned()),
            "og:description" => og_description = Some(content.to_owned()),
            "og:image" => og_image = Some(content.to_owned()),
            _ => {}
        }

        if name.eq_ignore_ascii_case("description") && meta_description.is_none() {
            meta_description = Some(content.to_owned());
        }
    }

    let html_title = document
        .select(&title_selector)
        .next()
        .map(|el| el.text().collect::<String>())
        .map(|text| text.trim().to_owned())
        .filter(|text| !text.is_empty());

    PageMetadata {
        title: og_title.or(html_title),
        description: og_description.or(meta_description),
        image_url: og_image,
    }
}

fn is_private_or_loopback_host(host: &str) -> bool {
    if let Ok(ip) = host.parse::<IpAddr>() {
        return is_private_or_loopback_ip(ip);
    }

    let normalized = host.trim_end_matches('.');
    normalized == "localhost" || normalized.ends_with(".local") || normalized.ends_with(".internal")
}

fn is_private_or_loopback_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            v4.is_loopback()
                || v4.is_private()
                || v4.is_link_local()
                || v4.is_broadcast()
                || v4.is_unspecified()
                || v4.octets()[0] == 100 && (v4.octets()[1] & 0xC0) == 64 // 100.64.0.0/10
        }
        IpAddr::V6(v6) => v6.is_loopback() || v6.is_unspecified(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_loopback_host() {
        assert!(is_private_or_loopback_host("localhost"));
        assert!(is_private_or_loopback_host("127.0.0.1"));
        assert!(is_private_or_loopback_host("::1"));
    }

    #[test]
    fn rejects_private_ip_hosts() {
        assert!(is_private_or_loopback_host("10.0.0.1"));
        assert!(is_private_or_loopback_host("192.168.1.1"));
        assert!(is_private_or_loopback_host("172.16.0.1"));
    }

    #[test]
    fn allows_public_hosts() {
        assert!(!is_private_or_loopback_host("example.com"));
        assert!(!is_private_or_loopback_host("8.8.8.8"));
        assert!(!is_private_or_loopback_host("1.1.1.1"));
    }

    #[test]
    fn extracts_og_metadata_from_html() {
        let html = r#"
            <html>
            <head>
                <meta property="og:title" content="Test Title">
                <meta property="og:description" content="Test Description">
                <meta property="og:image" content="https://example.com/image.png">
                <title>Fallback Title</title>
            </head>
            <body></body>
            </html>
        "#;

        let metadata = extract_metadata(html);
        assert_eq!(metadata.title.as_deref(), Some("Test Title"));
        assert_eq!(metadata.description.as_deref(), Some("Test Description"));
        assert_eq!(
            metadata.image_url.as_deref(),
            Some("https://example.com/image.png")
        );
    }

    #[test]
    fn falls_back_to_html_title_and_meta_description() {
        let html = r#"
            <html>
            <head>
                <meta name="description" content="Meta Description">
                <title>HTML Title</title>
            </head>
            <body></body>
            </html>
        "#;

        let metadata = extract_metadata(html);
        assert_eq!(metadata.title.as_deref(), Some("HTML Title"));
        assert_eq!(metadata.description.as_deref(), Some("Meta Description"));
        assert!(metadata.image_url.is_none());
    }

    #[test]
    fn returns_none_fields_for_empty_html() {
        let metadata = extract_metadata("<html><head></head><body></body></html>");
        assert!(metadata.title.is_none());
        assert!(metadata.description.is_none());
        assert!(metadata.image_url.is_none());
    }
}
