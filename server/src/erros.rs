use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

#[derive(Debug)]
pub enum ApiError {
    BadRequest(String),
    Unauthorized(String),
    Forbidden(String),
    NotFound(String),
    Conflict(String),
    Upstream(String),
    Internal(String),
}

impl ApiError {
    fn status(&self) -> StatusCode {
        match self {
            ApiError::BadRequest(_) => StatusCode::BAD_REQUEST,
            ApiError::Unauthorized(_) => StatusCode::UNAUTHORIZED,
            ApiError::Forbidden(_) => StatusCode::FORBIDDEN,
            ApiError::NotFound(_) => StatusCode::NOT_FOUND,
            ApiError::Conflict(_) => StatusCode::CONFLICT,
            ApiError::Upstream(_) => StatusCode::BAD_GATEWAY,
            ApiError::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    fn codigo(&self) -> &'static str {
        match self {
            ApiError::BadRequest(_) => "dados_invalidos",
            ApiError::Unauthorized(_) => "nao_autenticado",
            ApiError::Forbidden(_) => "sem_permissao",
            ApiError::NotFound(_) => "nao_encontrado",
            ApiError::Conflict(_) => "conflito",
            ApiError::Upstream(_) => "servico_externo_indisponivel",
            ApiError::Internal(_) => "erro_interno",
        }
    }

    fn mensagem(&self) -> &str {
        match self {
            ApiError::BadRequest(m)
            | ApiError::Unauthorized(m)
            | ApiError::Forbidden(m)
            | ApiError::NotFound(m)
            | ApiError::Conflict(m)
            | ApiError::Upstream(m)
            | ApiError::Internal(m) => m,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = self.status();
        if status.is_server_error() {
            tracing::error!(erro = ?self, "erro na API");
        } else {
            tracing::debug!(erro = ?self, "erro do cliente");
        }
        let corpo = json!({ "erro": self.codigo(), "mensagem": self.mensagem() });
        (status, Json(corpo)).into_response()
    }
}

impl From<sqlx::Error> for ApiError {
    fn from(e: sqlx::Error) -> Self {
        match e {
            sqlx::Error::RowNotFound => ApiError::NotFound("Registro não encontrado".into()),
            outro => ApiError::Internal(format!("Erro de banco de dados: {outro}")),
        }
    }
}

impl From<reqwest::Error> for ApiError {
    fn from(e: reqwest::Error) -> Self {
        ApiError::Upstream(format!("Falha ao consultar serviço externo: {e}"))
    }
}

impl From<anyhow::Error> for ApiError {
    fn from(e: anyhow::Error) -> Self {
        ApiError::Internal(e.to_string())
    }
}

pub type ApiResult<T> = Result<T, ApiError>;
