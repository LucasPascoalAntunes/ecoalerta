use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use axum::{
    extract::{FromRequestParts, OptionalFromRequestParts},
    http::{header::AUTHORIZATION, request::Parts},
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

use crate::{erros::ApiError, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: i64,
    pub nome: String,
    pub papel: String,
    pub exp: usize,
}

pub fn gerar_token(secret: &str, id: i64, nome: &str, papel: &str) -> Result<String, ApiError> {
    let exp = (chrono::Utc::now() + chrono::Duration::days(30)).timestamp() as usize;
    let claims = Claims { sub: id, nome: nome.to_string(), papel: papel.to_string(), exp };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret.as_bytes()))
        .map_err(|e| ApiError::Internal(format!("Falha ao gerar token: {e}")))
}

pub fn validar_token(secret: &str, token: &str) -> Result<Claims, ApiError> {
    decode::<Claims>(token, &DecodingKey::from_secret(secret.as_bytes()), &Validation::default())
        .map(|d| d.claims)
        .map_err(|_| ApiError::Unauthorized("Token inválido ou expirado".into()))
}

pub fn hash_senha(senha: &str) -> Result<String, ApiError> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(senha.as_bytes(), &salt)
        .map(|h| h.to_string())
        .map_err(|e| ApiError::Internal(format!("Falha ao proteger senha: {e}")))
}

pub fn verificar_senha(senha: &str, hash: &str) -> bool {
    match PasswordHash::new(hash) {
        Ok(parsed) => Argon2::default().verify_password(senha.as_bytes(), &parsed).is_ok(),
        Err(_) => false,
    }
}

#[derive(Debug, Clone)]
pub struct UsuarioAuth {
    pub id: i64,
    pub nome: String,
    pub papel: String,
}

impl UsuarioAuth {
    pub fn eh_gestor(&self) -> bool {
        self.papel == "gestor"
    }
}

fn extrair(parts: &Parts, state: &AppState) -> Result<Option<UsuarioAuth>, ApiError> {
    let Some(valor) = parts.headers.get(AUTHORIZATION) else {
        return Ok(None);
    };
    let texto = valor
        .to_str()
        .map_err(|_| ApiError::Unauthorized("Cabeçalho Authorization inválido".into()))?;
    let token = texto
        .strip_prefix("Bearer ")
        .ok_or_else(|| ApiError::Unauthorized("Use o formato: Bearer <token>".into()))?;
    let claims = validar_token(&state.jwt_secret, token.trim())?;
    Ok(Some(UsuarioAuth { id: claims.sub, nome: claims.nome, papel: claims.papel }))
}

impl FromRequestParts<AppState> for UsuarioAuth {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        extrair(parts, state)?
            .ok_or_else(|| ApiError::Unauthorized("Faça login para continuar".into()))
    }
}

impl OptionalFromRequestParts<AppState> for UsuarioAuth {
    type Rejection = ApiError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Option<Self>, ApiError> {
        extrair(parts, state)
    }
}

#[derive(Debug, Clone)]
pub struct GestorAuth(pub UsuarioAuth);

impl FromRequestParts<AppState> for GestorAuth {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let usuario =
            <UsuarioAuth as FromRequestParts<AppState>>::from_request_parts(parts, state).await?;
        if !usuario.eh_gestor() {
            return Err(ApiError::Forbidden("Apenas gestores podem executar esta ação".into()));
        }
        Ok(GestorAuth(usuario))
    }
}
