use axum::{extract::State, http::StatusCode, Json};

use crate::{
    auth::{gerar_token, hash_senha, verificar_senha, UsuarioAuth},
    erros::{ApiError, ApiResult},
    modelos::{agora, AuthResp, LoginReq, RegistrarReq, Usuario},
    AppState,
};

async fn buscar_usuario(state: &AppState, id: i64) -> ApiResult<Usuario> {
    Ok(sqlx::query_as::<_, Usuario>(
        "SELECT id, nome, email, papel, criado_em FROM usuarios WHERE id = ?",
    )
    .bind(id)
    .fetch_one(&state.pool)
    .await?)
}

pub async fn registrar(
    State(state): State<AppState>,
    Json(req): Json<RegistrarReq>,
) -> ApiResult<(StatusCode, Json<AuthResp>)> {
    let nome = req.nome.trim().to_string();
    let email = req.email.trim().to_lowercase();
    if nome.chars().count() < 2 || nome.chars().count() > 80 {
        return Err(ApiError::BadRequest("Informe um nome com 2 a 80 caracteres".into()));
    }
    if !email.contains('@') || !email.contains('.') || email.len() > 120 {
        return Err(ApiError::BadRequest("Informe um e-mail válido".into()));
    }
    if req.senha.chars().count() < 6 {
        return Err(ApiError::BadRequest("A senha deve ter pelo menos 6 caracteres".into()));
    }
    let existe: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM usuarios WHERE email = ?")
        .bind(&email)
        .fetch_one(&state.pool)
        .await?;
    if existe > 0 {
        return Err(ApiError::Conflict("Já existe uma conta com este e-mail".into()));
    }

    let senha = req.senha.clone();
    let hash = tokio::task::spawn_blocking(move || hash_senha(&senha))
        .await
        .map_err(|e| ApiError::Internal(format!("Falha interna: {e}")))??;

    let id = sqlx::query(
        "INSERT INTO usuarios (nome, email, senha_hash, papel, criado_em) VALUES (?, ?, ?, 'cidadao', ?)",
    )
    .bind(&nome)
    .bind(&email)
    .bind(hash)
    .bind(agora())
    .execute(&state.pool)
    .await?
    .last_insert_rowid();

    let usuario = buscar_usuario(&state, id).await?;
    let token = gerar_token(&state.jwt_secret, usuario.id, &usuario.nome, &usuario.papel)?;
    tracing::info!(usuario = %usuario.email, "novo cadastro");
    state.emitir("usuario_cadastrado", serde_json::json!({ "nome": usuario.nome }));
    Ok((StatusCode::CREATED, Json(AuthResp { token, usuario })))
}

pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginReq>,
) -> ApiResult<Json<AuthResp>> {
    let email = req.email.trim().to_lowercase();
    let linha = sqlx::query_as::<_, (i64, String)>(
        "SELECT id, senha_hash FROM usuarios WHERE email = ?",
    )
    .bind(&email)
    .fetch_optional(&state.pool)
    .await?;

    let Some((id, hash)) = linha else {
        return Err(ApiError::Unauthorized("E-mail ou senha incorretos".into()));
    };
    let senha = req.senha.clone();
    let ok = tokio::task::spawn_blocking(move || verificar_senha(&senha, &hash))
        .await
        .map_err(|e| ApiError::Internal(format!("Falha interna: {e}")))?;
    if !ok {
        return Err(ApiError::Unauthorized("E-mail ou senha incorretos".into()));
    }
    let usuario = buscar_usuario(&state, id).await?;
    let token = gerar_token(&state.jwt_secret, usuario.id, &usuario.nome, &usuario.papel)?;
    tracing::info!(usuario = %usuario.email, "login efetuado");
    Ok(Json(AuthResp { token, usuario }))
}

pub async fn eu(State(state): State<AppState>, usuario: UsuarioAuth) -> ApiResult<Json<Usuario>> {
    Ok(Json(buscar_usuario(&state, usuario.id).await?))
}
