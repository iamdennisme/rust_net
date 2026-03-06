use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::str::FromStr;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use base64::Engine;
use base64::prelude::BASE64_STANDARD;
use once_cell::sync::Lazy;
use reqwest::Method;
use reqwest::blocking::{Client, ClientBuilder};
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};

static CLIENTS: Lazy<Mutex<HashMap<u64, ClientEntry>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT_CLIENT_ID: AtomicU64 = AtomicU64::new(1);

#[derive(Clone)]
struct ClientEntry {
    client: Client,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpClientConfig {
    default_headers: HashMap<String, String>,
    timeout_ms: Option<u64>,
    user_agent: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpRequest {
    method: String,
    url: String,
    headers: HashMap<String, String>,
    body_base64: Option<String>,
    timeout_ms: Option<u64>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpResponse {
    status_code: u16,
    headers: HashMap<String, Vec<String>>,
    body_base64: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpError {
    code: String,
    message: String,
    status_code: Option<u16>,
    is_timeout: bool,
    uri: Option<String>,
    details: Option<HashMap<String, String>>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum NativeHttpResult {
    Success { response: NativeHttpResponse },
    Error { error: NativeHttpError },
}

#[derive(Debug)]
struct NativeError {
    code: &'static str,
    message: String,
    status_code: Option<u16>,
    is_timeout: bool,
    uri: Option<String>,
    details: Option<HashMap<String, String>>,
}

impl NativeError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            status_code: None,
            is_timeout: false,
            uri: None,
            details: None,
        }
    }

    fn with_uri(mut self, uri: impl Into<String>) -> Self {
        self.uri = Some(uri.into());
        self
    }

    fn with_timeout(mut self) -> Self {
        self.is_timeout = true;
        self
    }

    fn with_details(mut self, details: HashMap<String, String>) -> Self {
        self.details = Some(details);
        self
    }

    fn into_result(self) -> NativeHttpResult {
        NativeHttpResult::Error {
            error: NativeHttpError {
                code: self.code.to_string(),
                message: self.message,
                status_code: self.status_code,
                is_timeout: self.is_timeout,
                uri: self.uri,
                details: self.details,
            },
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_create(config_json: *const c_char) -> u64 {
    let config = match read_json::<NativeHttpClientConfig>(config_json) {
        Ok(config) => config,
        Err(_) => return 0,
    };
    let client = match build_client(&config) {
        Ok(client) => client,
        Err(_) => return 0,
    };

    let client_id = NEXT_CLIENT_ID.fetch_add(1, Ordering::Relaxed);
    let entry = ClientEntry { client };
    CLIENTS.lock().unwrap().insert(client_id, entry);
    client_id
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_execute(
    client_id: u64,
    request_json: *const c_char,
) -> *mut c_char {
    let result = match read_json::<NativeHttpRequest>(request_json) {
        Ok(request) => match execute_request(client_id, request) {
            Ok(response) => NativeHttpResult::Success { response },
            Err(error) => error.into_result(),
        },
        Err(error) => error.into_result(),
    };

    serialize_result(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_close(client_id: u64) {
    CLIENTS.lock().unwrap().remove(&client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_string_free(value: *mut c_char) {
    if value.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(value));
    }
}

fn read_json<T>(pointer: *const c_char) -> Result<T, NativeError>
where
    T: DeserializeOwned,
{
    if pointer.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null JSON pointer.",
        ));
    }

    let json = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map_err(|error| NativeError::new("invalid_utf8", error.to_string()))?;

    serde_json::from_str(json)
        .map_err(|error| NativeError::new("invalid_json", error.to_string()))
}

fn build_client(config: &NativeHttpClientConfig) -> Result<Client, NativeError> {
    let mut builder = ClientBuilder::new();

    if let Some(timeout_ms) = config.timeout_ms.filter(|value| *value > 0) {
        builder = builder.timeout(Duration::from_millis(timeout_ms));
    }

    if let Some(user_agent) = config.user_agent.as_ref().filter(|value| !value.is_empty()) {
        builder = builder.user_agent(user_agent.clone());
    }

    if !config.default_headers.is_empty() {
        builder = builder.default_headers(build_headers(
            &config.default_headers,
            "invalid_config",
        )?);
    }

    builder
        .build()
        .map_err(|error| NativeError::new("invalid_config", error.to_string()))
}

fn execute_request(
    client_id: u64,
    request: NativeHttpRequest,
) -> Result<NativeHttpResponse, NativeError> {
    let client = {
        let clients = CLIENTS.lock().unwrap();
        let entry = clients
            .get(&client_id)
            .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
        entry.client.clone()
    };

    let method = Method::from_str(&request.method)
        .map_err(|error| NativeError::new("invalid_request", error.to_string()))?;

    let mut builder = client.request(method, &request.url);

    for (name, value) in &request.headers {
        let header_name = HeaderName::from_bytes(name.as_bytes()).map_err(|error| {
            let mut details = HashMap::new();
            details.insert("header".to_string(), name.clone());
            NativeError::new("invalid_request", error.to_string()).with_details(details)
        })?;
        let header_value = HeaderValue::from_str(value).map_err(|error| {
            let mut details = HashMap::new();
            details.insert("header".to_string(), name.clone());
            NativeError::new("invalid_request", error.to_string()).with_details(details)
        })?;
        builder = builder.header(header_name, header_value);
    }

    if let Some(timeout_ms) = request.timeout_ms.filter(|value| *value > 0) {
        builder = builder.timeout(Duration::from_millis(timeout_ms));
    }

    if let Some(body_base64) = request.body_base64.as_ref() {
        let bytes = BASE64_STANDARD.decode(body_base64).map_err(|error| {
            NativeError::new("invalid_request", error.to_string()).with_uri(request.url.clone())
        })?;
        builder = builder.body(bytes);
    }

    let response = builder.send().map_err(|error| map_reqwest_error(error, &request.url))?;
    let status_code = response.status().as_u16();

    let mut headers = HashMap::<String, Vec<String>>::new();
    for (name, value) in response.headers() {
        let value_string = value.to_str().unwrap_or_default().to_string();
        headers
            .entry(name.to_string())
            .or_default()
            .push(value_string);
    }

    let body = response
        .bytes()
        .map_err(|error| map_reqwest_error(error, &request.url))?;

    Ok(NativeHttpResponse {
        status_code,
        headers,
        body_base64: BASE64_STANDARD.encode(body),
    })
}

fn build_headers(
    headers: &HashMap<String, String>,
    error_code: &'static str,
) -> Result<HeaderMap, NativeError> {
    let mut header_map = HeaderMap::new();
    for (name, value) in headers {
        let header_name = HeaderName::from_bytes(name.as_bytes())
            .map_err(|error| NativeError::new(error_code, error.to_string()))?;
        let header_value = HeaderValue::from_str(value)
            .map_err(|error| NativeError::new(error_code, error.to_string()))?;
        header_map.insert(header_name, header_value);
    }
    Ok(header_map)
}

fn map_reqwest_error(error: reqwest::Error, url: &str) -> NativeError {
    if error.is_timeout() {
        return NativeError::new("timeout", error.to_string())
            .with_timeout()
            .with_uri(url.to_string());
    }

    NativeError::new("network", error.to_string()).with_uri(url.to_string())
}

fn serialize_result(result: NativeHttpResult) -> *mut c_char {
    match serde_json::to_string(&result)
        .ok()
        .and_then(|json| CString::new(json).ok())
    {
        Some(value) => value.into_raw(),
        None => CString::new(
            r#"{"type":"error","error":{"code":"serialization","message":"Failed to encode response.","is_timeout":false}}"#,
        )
        .unwrap()
        .into_raw(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use httpmock::Method::GET;
    use httpmock::MockServer;

    #[test]
    fn executes_http_requests_and_collects_response_data() {
        let server = MockServer::start();
        let mock = server.mock(|when, then| {
            when.method(GET).path("/hello");
            then.status(200)
                .header("content-type", "text/plain")
                .body("world");
        });

        let client = build_client(&NativeHttpClientConfig::default()).unwrap();
        let response = execute_request_with_client(
            &client,
            NativeHttpRequest {
                method: "GET".to_string(),
                url: server.url("/hello"),
                headers: HashMap::new(),
                body_base64: None,
                timeout_ms: None,
            },
        )
        .unwrap();

        mock.assert();
        assert_eq!(response.status_code, 200);
        assert_eq!(BASE64_STANDARD.decode(response.body_base64).unwrap(), b"world");
        assert_eq!(
            response.headers.get("content-type"),
            Some(&vec!["text/plain".to_string()])
        );
    }

    #[test]
    fn marks_timeout_errors() {
        let server = MockServer::start();
        server.mock(|when, then| {
            when.method(GET).path("/slow");
            then.status(200)
                .delay(Duration::from_millis(50))
                .body("slow");
        });

        let client = build_client(&NativeHttpClientConfig::default()).unwrap();
        let error = execute_request_with_client(
            &client,
            NativeHttpRequest {
                method: "GET".to_string(),
                url: server.url("/slow"),
                headers: HashMap::new(),
                body_base64: None,
                timeout_ms: Some(5),
            },
        )
        .unwrap_err();

        assert_eq!(error.code, "timeout");
        assert!(error.is_timeout);
    }

    #[test]
    fn rejects_unknown_client_handles() {
        let error = execute_request(
            u64::MAX,
            NativeHttpRequest {
                method: "GET".to_string(),
                url: "https://example.com".to_string(),
                headers: HashMap::new(),
                body_base64: None,
                timeout_ms: None,
            },
        )
        .unwrap_err();

        assert_eq!(error.code, "invalid_client");
    }

    #[test]
    fn rejects_invalid_http_methods() {
        let client = build_client(&NativeHttpClientConfig::default()).unwrap();
        let error = execute_request_with_client(
            &client,
            NativeHttpRequest {
                method: "NOT VALID".to_string(),
                url: "https://example.com".to_string(),
                headers: HashMap::new(),
                body_base64: None,
                timeout_ms: None,
            },
        )
        .unwrap_err();

        assert_eq!(error.code, "invalid_request");
    }

    fn execute_request_with_client(
        client: &Client,
        request: NativeHttpRequest,
    ) -> Result<NativeHttpResponse, NativeError> {
        let method = Method::from_str(&request.method)
            .map_err(|error| NativeError::new("invalid_request", error.to_string()))?;

        let mut builder = client.request(method, &request.url);
        if let Some(timeout_ms) = request.timeout_ms.filter(|value| *value > 0) {
            builder = builder.timeout(Duration::from_millis(timeout_ms));
        }

        let response = builder.send().map_err(|error| map_reqwest_error(error, &request.url))?;
        let status_code = response.status().as_u16();
        let mut headers = HashMap::<String, Vec<String>>::new();
        for (name, value) in response.headers() {
            headers
                .entry(name.to_string())
                .or_default()
                .push(value.to_str().unwrap_or_default().to_string());
        }
        let body = response
            .bytes()
            .map_err(|error| map_reqwest_error(error, &request.url))?;

        Ok(NativeHttpResponse {
            status_code,
            headers,
            body_base64: BASE64_STANDARD.encode(body),
        })
    }
}
