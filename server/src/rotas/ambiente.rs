use axum::{
    extract::{Query, State},
    Json,
};
use serde::Serialize;
use serde_json::{json, Value};
use sqlx::FromRow;

use crate::{
    auth::GestorAuth,
    coletor, externo,
    erros::{ApiError, ApiResult},
    externo::{Clima, Endereco, QualidadeAr},
    modelos::{distancia_km, AmostraAr, CoordQuery, HistoricoQuery, PontoMonitorado},
    AppState,
};

fn validar(lat: f64, lon: f64) -> ApiResult<()> {
    if !(-90.0..=90.0).contains(&lat) || !(-180.0..=180.0).contains(&lon) {
        return Err(ApiError::BadRequest("Coordenadas fora do intervalo válido".into()));
    }
    Ok(())
}

pub async fn ar(State(state): State<AppState>, Query(q): Query<CoordQuery>) -> ApiResult<Json<QualidadeAr>> {
    validar(q.lat, q.lon)?;
    Ok(Json(externo::qualidade_ar(&state.externo, q.lat, q.lon).await?))
}

pub async fn clima(State(state): State<AppState>, Query(q): Query<CoordQuery>) -> ApiResult<Json<Clima>> {
    validar(q.lat, q.lon)?;
    Ok(Json(externo::clima(&state.externo, q.lat, q.lon).await?))
}

pub async fn geocode(State(state): State<AppState>, Query(q): Query<CoordQuery>) -> ApiResult<Json<Endereco>> {
    validar(q.lat, q.lon)?;
    Ok(Json(externo::geocode_reverso(&state.externo, q.lat, q.lon).await?))
}

#[derive(Debug, Serialize, FromRow)]
pub struct PontoComAmostra {
    pub id: i64,
    pub nome: String,
    pub latitude: f64,
    pub longitude: f64,
    pub aqi_eu: Option<f64>,
    pub pm2_5: Option<f64>,
    pub pm10: Option<f64>,
    pub coletado_em: Option<String>,
    pub total_amostras: i64,
}

pub async fn pontos(State(state): State<AppState>) -> ApiResult<Json<Vec<PontoComAmostra>>> {
    let lista = sqlx::query_as::<_, PontoComAmostra>(
        "SELECT p.id, p.nome, p.latitude, p.longitude, a.aqi_eu, a.pm2_5, a.pm10, a.coletado_em,
                (SELECT COUNT(*) FROM amostras_ar x WHERE x.ponto_id = p.id) AS total_amostras
         FROM pontos_monitorados p
         LEFT JOIN amostras_ar a ON a.id = (SELECT id FROM amostras_ar WHERE ponto_id = p.id ORDER BY coletado_em DESC LIMIT 1)
         ORDER BY p.id",
    )
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(lista))
}

pub async fn historico(State(state): State<AppState>, Query(q): Query<HistoricoQuery>) -> ApiResult<Json<Value>> {
    let pontos = sqlx::query_as::<_, PontoMonitorado>(
        "SELECT id, nome, latitude, longitude FROM pontos_monitorados ORDER BY id",
    )
    .fetch_all(&state.pool)
    .await?;
    if pontos.is_empty() {
        return Err(ApiError::NotFound("Nenhum ponto monitorado cadastrado".into()));
    }
    let ponto = if let Some(id) = q.ponto_id {
        pontos.iter().find(|p| p.id == id).cloned().ok_or_else(|| ApiError::NotFound("Ponto monitorado não encontrado".into()))?
    } else if let (Some(lat), Some(lon)) = (q.lat, q.lon) {
        pontos
            .iter()
            .min_by(|a, b| {
                distancia_km(lat, lon, a.latitude, a.longitude)
                    .partial_cmp(&distancia_km(lat, lon, b.latitude, b.longitude))
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
            .cloned()
            .unwrap()
    } else {
        pontos[0].clone()
    };
    let horas = q.horas.unwrap_or(168).clamp(1, 720);
    let desde = (chrono::Utc::now() - chrono::Duration::hours(horas))
        .to_rfc3339_opts(chrono::SecondsFormat::Secs, true);
    let amostras = sqlx::query_as::<_, AmostraAr>(
        "SELECT id, ponto_id, aqi_eu, pm2_5, pm10, no2, o3, coletado_em FROM amostras_ar
         WHERE ponto_id = ? AND coletado_em >= ? ORDER BY coletado_em",
    )
    .bind(ponto.id)
    .bind(desde)
    .fetch_all(&state.pool)
    .await?;
    let distancia = match (q.lat, q.lon) {
        (Some(lat), Some(lon)) => Some(distancia_km(lat, lon, ponto.latitude, ponto.longitude)),
        _ => None,
    };
    Ok(Json(json!({ "ponto": ponto, "distancia_km": distancia, "horas": horas, "amostras": amostras })))
}

pub async fn coletar_agora(State(state): State<AppState>, GestorAuth(g): GestorAuth) -> ApiResult<Json<Value>> {
    tracing::info!(gestor = %g.nome, "coleta manual solicitada");
    let n = coletor::coletar(&state).await.map_err(|e| ApiError::Upstream(e.to_string()))?;
    Ok(Json(json!({ "pontos_coletados": n })))
}
