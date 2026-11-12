use std::collections::HashSet;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use base64::Engine;
use serde_json::{json, Value};

use crate::{
    auth::{GestorAuth, UsuarioAuth},
    erros::{ApiError, ApiResult},
    externo,
    modelos::{
        agora, categoria_valida, distancia_km, AlterarStatusReq, Comentario, FiltroRelatos,
        HistoricoStatus, NovoComentarioReq, NovoRelatoReq, Relato, CATEGORIAS, STATUS,
    },
    AppState,
};

pub const BASE_SELECT: &str = "SELECT r.id, r.usuario_id, u.nome AS autor_nome, r.categoria, r.titulo, r.descricao,
        r.gravidade, r.status, r.latitude, r.longitude, r.endereco, r.bairro, r.cidade, r.foto_url,
        r.confirmacoes, (SELECT COUNT(*) FROM comentarios c WHERE c.relato_id = r.id) AS comentarios_qtd,
        r.criado_em, r.atualizado_em, r.resolvido_em
     FROM relatos r JOIN usuarios u ON u.id = r.usuario_id";

pub async fn buscar_relato(state: &AppState, id: i64) -> ApiResult<Relato> {
    sqlx::query_as::<_, Relato>(&format!("{BASE_SELECT} WHERE r.id = ?"))
        .bind(id)
        .fetch_optional(&state.pool)
        .await?
        .ok_or_else(|| ApiError::NotFound(format!("Relato #{id} não encontrado")))
}

async fn marcar_confirmados(state: &AppState, usuario: &Option<UsuarioAuth>, lista: &mut [Relato]) -> ApiResult<()> {
    if let Some(u) = usuario {
        let ids: Vec<i64> = sqlx::query_scalar("SELECT relato_id FROM confirmacoes WHERE usuario_id = ?")
            .bind(u.id)
            .fetch_all(&state.pool)
            .await?;
        let set: HashSet<i64> = ids.into_iter().collect();
        for r in lista.iter_mut() {
            r.confirmado_por_mim = set.contains(&r.id);
        }
    }
    Ok(())
}

pub async fn categorias() -> Json<Value> {
    let lista: Vec<Value> = CATEGORIAS
        .iter()
        .map(|(id, nome, icone, descricao)| json!({ "id": id, "nome": nome, "icone": icone, "descricao": descricao }))
        .collect();
    Json(json!({ "categorias": lista, "status": STATUS }))
}

pub async fn listar(
    State(state): State<AppState>,
    usuario: Option<UsuarioAuth>,
    Query(f): Query<FiltroRelatos>,
) -> ApiResult<Json<Vec<Relato>>> {
    let mut sql = format!("{BASE_SELECT} WHERE 1=1");
    let mut textos: Vec<String> = Vec::new();

    if let Some(c) = f.categoria.as_deref().filter(|c| !c.is_empty()) {
        if !categoria_valida(c) {
            return Err(ApiError::BadRequest(format!("Categoria desconhecida: {c}")));
        }
        sql.push_str(" AND r.categoria = ?");
        textos.push(c.to_string());
    }
    if let Some(s) = f.status.as_deref().filter(|s| !s.is_empty()) {
        if !STATUS.contains(&s) {
            return Err(ApiError::BadRequest(format!("Status desconhecido: {s}")));
        }
        sql.push_str(" AND r.status = ?");
        textos.push(s.to_string());
    }
    if let Some(b) = f.busca.as_deref().map(str::trim).filter(|b| !b.is_empty()) {
        sql.push_str(" AND (r.titulo LIKE ? OR r.descricao LIKE ? OR r.bairro LIKE ? OR r.endereco LIKE ?)");
        let padrao = format!("%{b}%");
        for _ in 0..4 {
            textos.push(padrao.clone());
        }
    }
    let mut filtro_usuario: Option<i64> = None;
    if f.meus == Some(true) {
        match &usuario {
            Some(u) => {
                sql.push_str(" AND r.usuario_id = ?");
                filtro_usuario = Some(u.id);
            }
            None => return Err(ApiError::Unauthorized("Faça login para ver seus relatos".into())),
        }
    }
    sql.push_str(" ORDER BY r.criado_em DESC LIMIT ?");
    let limite = f.limite.unwrap_or(300).clamp(1, 2000) as usize;
    let limite_sql: i64 = if f.lat.is_some() && f.lon.is_some() { 2000 } else { limite as i64 };

    let mut consulta = sqlx::query_as::<_, Relato>(&sql);
    for t in &textos {
        consulta = consulta.bind(t);
    }
    if let Some(uid) = filtro_usuario {
        consulta = consulta.bind(uid);
    }
    consulta = consulta.bind(limite_sql);
    let mut lista = consulta.fetch_all(&state.pool).await?;

    if let (Some(lat), Some(lon)) = (f.lat, f.lon) {
        for r in lista.iter_mut() {
            r.distancia_km = Some(distancia_km(lat, lon, r.latitude, r.longitude));
        }
        if let Some(raio) = f.raio_km {
            lista.retain(|r| r.distancia_km.unwrap_or(f64::MAX) <= raio);
        }
        if f.ordenar.as_deref() == Some("distancia") {
            lista.sort_by(|a, b| a.distancia_km.partial_cmp(&b.distancia_km).unwrap_or(std::cmp::Ordering::Equal));
        }
    }
    lista.truncate(limite);
    marcar_confirmados(&state, &usuario, &mut lista).await?;
    Ok(Json(lista))
}

pub async fn obter(
    State(state): State<AppState>,
    usuario: Option<UsuarioAuth>,
    Path(id): Path<i64>,
) -> ApiResult<Json<Relato>> {
    let relato = buscar_relato(&state, id).await?;
    let mut lista = vec![relato];
    marcar_confirmados(&state, &usuario, &mut lista).await?;
    Ok(Json(lista.remove(0)))
}

async fn salvar_foto(state: &AppState, b64: &str) -> ApiResult<String> {
    let dados = b64.split(',').next_back().unwrap_or(b64).trim();
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(dados)
        .map_err(|_| ApiError::BadRequest("Foto em Base64 inválida".into()))?;
    if bytes.len() > 8 * 1024 * 1024 {
        return Err(ApiError::BadRequest("Foto maior que 8 MB".into()));
    }
    let ext = if bytes.starts_with(&[0x89, 0x50, 0x4E, 0x47]) {
        "png"
    } else if bytes.starts_with(&[0xFF, 0xD8]) {
        "jpg"
    } else if bytes.starts_with(b"RIFF") {
        "webp"
    } else {
        return Err(ApiError::BadRequest("Formato de imagem não suportado (use JPG, PNG ou WebP)".into()));
    };
    let nome = format!("{}.{ext}", uuid::Uuid::new_v4());
    let caminho = state.uploads_dir.join(&nome);
    tokio::fs::write(&caminho, &bytes)
        .await
        .map_err(|e| ApiError::Internal(format!("Não foi possível salvar a foto: {e}")))?;
    Ok(format!("/uploads/{nome}"))
}

pub async fn criar(
    State(state): State<AppState>,
    usuario: UsuarioAuth,
    Json(req): Json<NovoRelatoReq>,
) -> ApiResult<(StatusCode, Json<Relato>)> {
    let titulo = req.titulo.trim().to_string();
    let descricao = req.descricao.trim().to_string();
    if !categoria_valida(&req.categoria) {
        return Err(ApiError::BadRequest("Escolha uma categoria válida".into()));
    }
    if titulo.chars().count() < 5 || titulo.chars().count() > 120 {
        return Err(ApiError::BadRequest("O título deve ter entre 5 e 120 caracteres".into()));
    }
    if descricao.chars().count() < 10 || descricao.chars().count() > 2000 {
        return Err(ApiError::BadRequest("A descrição deve ter entre 10 e 2000 caracteres".into()));
    }
    if !(1..=5).contains(&req.gravidade) {
        return Err(ApiError::BadRequest("A gravidade deve ser de 1 a 5".into()));
    }
    if !(-90.0..=90.0).contains(&req.latitude) || !(-180.0..=180.0).contains(&req.longitude) {
        return Err(ApiError::BadRequest("Coordenadas inválidas".into()));
    }

    let foto_url = match req.foto_base64.as_deref().filter(|s| !s.is_empty()) {
        Some(b64) => Some(salvar_foto(&state, b64).await?),
        None => None,
    };

    let (endereco, bairro, cidade) = match req.endereco.as_deref().map(str::trim).filter(|e| !e.is_empty()) {
        Some(e) => (Some(e.to_string()), req.bairro.clone(), req.cidade.clone()),
        None => match tokio::time::timeout(
            std::time::Duration::from_secs(6),
            externo::geocode_reverso(&state.externo, req.latitude, req.longitude),
        )
        .await
        {
            Ok(Ok(g)) => (Some(g.endereco), g.bairro.or(req.bairro.clone()), g.cidade.or(req.cidade.clone())),
            _ => (None, req.bairro.clone(), req.cidade.clone()),
        },
    };

    let agora_txt = agora();
    let criado_em = req
        .criado_offline_em
        .as_deref()
        .filter(|s| chrono::DateTime::parse_from_rfc3339(s).is_ok())
        .map(|s| s.to_string())
        .unwrap_or_else(|| agora_txt.clone());

    let id = sqlx::query(
        "INSERT INTO relatos (usuario_id, categoria, titulo, descricao, gravidade, status, latitude, longitude,
                              endereco, bairro, cidade, foto_url, confirmacoes, criado_em, atualizado_em)
         VALUES (?, ?, ?, ?, ?, 'aberto', ?, ?, ?, ?, ?, ?, 0, ?, ?)",
    )
    .bind(usuario.id)
    .bind(&req.categoria)
    .bind(&titulo)
    .bind(&descricao)
    .bind(req.gravidade)
    .bind(req.latitude)
    .bind(req.longitude)
    .bind(&endereco)
    .bind(&bairro)
    .bind(&cidade)
    .bind(&foto_url)
    .bind(&criado_em)
    .bind(&agora_txt)
    .execute(&state.pool)
    .await?
    .last_insert_rowid();

    let relato = buscar_relato(&state, id).await?;
    tracing::info!(id, categoria = %relato.categoria, autor = %usuario.nome, "relato criado");
    state.emitir("relato_criado", json!(relato));
    Ok((StatusCode::CREATED, Json(relato)))
}

pub async fn confirmar(
    State(state): State<AppState>,
    usuario: UsuarioAuth,
    Path(id): Path<i64>,
) -> ApiResult<Json<Relato>> {
    let relato = buscar_relato(&state, id).await?;
    if relato.usuario_id == usuario.id {
        return Err(ApiError::BadRequest("Você não pode confirmar o próprio relato".into()));
    }
    let inseriu = sqlx::query("INSERT OR IGNORE INTO confirmacoes (relato_id, usuario_id, criado_em) VALUES (?, ?, ?)")
        .bind(id)
        .bind(usuario.id)
        .bind(agora())
        .execute(&state.pool)
        .await?
        .rows_affected()
        > 0;
    if !inseriu {
        sqlx::query("DELETE FROM confirmacoes WHERE relato_id = ? AND usuario_id = ?")
            .bind(id)
            .bind(usuario.id)
            .execute(&state.pool)
            .await?;
    }
    sqlx::query(
        "UPDATE relatos SET confirmacoes = (SELECT COUNT(*) FROM confirmacoes WHERE relato_id = ?), atualizado_em = ? WHERE id = ?",
    )
    .bind(id)
    .bind(agora())
    .bind(id)
    .execute(&state.pool)
    .await?;
    let mut relato = buscar_relato(&state, id).await?;
    relato.confirmado_por_mim = inseriu;
    state.emitir(
        "relato_confirmado",
        json!({ "id": id, "titulo": relato.titulo, "confirmacoes": relato.confirmacoes, "por": usuario.nome, "confirmou": inseriu }),
    );
    Ok(Json(relato))
}

pub async fn alterar_status(
    State(state): State<AppState>,
    GestorAuth(gestor): GestorAuth,
    Path(id): Path<i64>,
    Json(req): Json<AlterarStatusReq>,
) -> ApiResult<Json<Relato>> {
    if !STATUS.contains(&req.status.as_str()) {
        return Err(ApiError::BadRequest(format!("Status inválido: {}", req.status)));
    }
    let atual = buscar_relato(&state, id).await?;
    if atual.status == req.status {
        return Err(ApiError::BadRequest("O relato já está neste status".into()));
    }
    let agora_txt = agora();
    let resolvido_em: Option<String> = if req.status == "resolvido" { Some(agora_txt.clone()) } else { None };
    sqlx::query("UPDATE relatos SET status = ?, atualizado_em = ?, resolvido_em = ? WHERE id = ?")
        .bind(&req.status)
        .bind(&agora_txt)
        .bind(&resolvido_em)
        .bind(id)
        .execute(&state.pool)
        .await?;
    sqlx::query(
        "INSERT INTO historico_status (relato_id, usuario_id, de_status, para_status, observacao, criado_em) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(id)
    .bind(gestor.id)
    .bind(&atual.status)
    .bind(&req.status)
    .bind(req.observacao.as_deref().map(str::trim).filter(|o| !o.is_empty()))
    .bind(&agora_txt)
    .execute(&state.pool)
    .await?;
    let relato = buscar_relato(&state, id).await?;
    tracing::info!(id, de = %atual.status, para = %req.status, gestor = %gestor.nome, "status alterado");
    state.emitir("status_alterado", json!({ "relato": relato, "de": atual.status, "por": gestor.nome, "observacao": req.observacao }));
    Ok(Json(relato))
}

pub async fn historico(State(state): State<AppState>, Path(id): Path<i64>) -> ApiResult<Json<Vec<HistoricoStatus>>> {
    buscar_relato(&state, id).await?;
    let lista = sqlx::query_as::<_, HistoricoStatus>(
        "SELECT h.id, h.relato_id, u.nome AS autor_nome, h.de_status, h.para_status, h.observacao, h.criado_em
         FROM historico_status h JOIN usuarios u ON u.id = h.usuario_id WHERE h.relato_id = ? ORDER BY h.criado_em",
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(lista))
}

pub async fn listar_comentarios(State(state): State<AppState>, Path(id): Path<i64>) -> ApiResult<Json<Vec<Comentario>>> {
    buscar_relato(&state, id).await?;
    let lista = sqlx::query_as::<_, Comentario>(
        "SELECT c.id, c.relato_id, c.usuario_id, u.nome AS autor_nome, c.texto, c.criado_em
         FROM comentarios c JOIN usuarios u ON u.id = c.usuario_id WHERE c.relato_id = ? ORDER BY c.criado_em",
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(lista))
}

pub async fn comentar(
    State(state): State<AppState>,
    usuario: UsuarioAuth,
    Path(id): Path<i64>,
    Json(req): Json<NovoComentarioReq>,
) -> ApiResult<(StatusCode, Json<Comentario>)> {
    let texto = req.texto.trim().to_string();
    if texto.is_empty() || texto.chars().count() > 1000 {
        return Err(ApiError::BadRequest("O comentário deve ter entre 1 e 1000 caracteres".into()));
    }
    buscar_relato(&state, id).await?;
    let cid = sqlx::query("INSERT INTO comentarios (relato_id, usuario_id, texto, criado_em) VALUES (?, ?, ?, ?)")
        .bind(id)
        .bind(usuario.id)
        .bind(&texto)
        .bind(agora())
        .execute(&state.pool)
        .await?
        .last_insert_rowid();
    let comentario = sqlx::query_as::<_, Comentario>(
        "SELECT c.id, c.relato_id, c.usuario_id, u.nome AS autor_nome, c.texto, c.criado_em
         FROM comentarios c JOIN usuarios u ON u.id = c.usuario_id WHERE c.id = ?",
    )
    .bind(cid)
    .fetch_one(&state.pool)
    .await?;
    state.emitir("comentario_criado", json!({ "relato_id": id, "comentario": comentario }));
    Ok((StatusCode::CREATED, Json(comentario)))
}

pub async fn excluir(
    State(state): State<AppState>,
    usuario: UsuarioAuth,
    Path(id): Path<i64>,
) -> ApiResult<Json<Value>> {
    let relato = buscar_relato(&state, id).await?;
    if relato.usuario_id != usuario.id && !usuario.eh_gestor() {
        return Err(ApiError::Forbidden("Somente o autor ou um gestor pode excluir este relato".into()));
    }
    sqlx::query("DELETE FROM relatos WHERE id = ?").bind(id).execute(&state.pool).await?;
    if let Some(url) = relato.foto_url.as_deref().and_then(|u| u.strip_prefix("/uploads/")) {
        let _ = tokio::fs::remove_file(state.uploads_dir.join(url)).await;
    }
    tracing::info!(id, por = %usuario.nome, "relato excluído");
    state.emitir("relato_excluido", json!({ "id": id, "titulo": relato.titulo }));
    Ok(Json(json!({ "ok": true, "id": id })))
}
