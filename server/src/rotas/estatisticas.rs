use axum::{
    extract::State,
    http::header::{CONTENT_DISPOSITION, CONTENT_TYPE},
    Json,
};
use serde::Serialize;
use sqlx::FromRow;

use crate::{
    erros::ApiResult,
    modelos::{agora, Relato, CATEGORIAS},
    rotas::relatos::BASE_SELECT,
    AppState,
};

#[derive(Debug, Serialize, FromRow)]
pub struct Contagem {
    pub nome: String,
    pub total: i64,
}

#[derive(Debug, Serialize)]
pub struct Estatisticas {
    pub total_relatos: i64,
    pub abertos: i64,
    pub em_analise: i64,
    pub resolvidos: i64,
    pub invalidos: i64,
    pub ultimos_7_dias: i64,
    pub ultimas_24h: i64,
    pub total_usuarios: i64,
    pub total_confirmacoes: i64,
    pub total_comentarios: i64,
    pub total_amostras_ar: i64,
    pub taxa_resolucao_pct: f64,
    pub tempo_medio_resolucao_horas: Option<f64>,
    pub gravidade_media: Option<f64>,
    pub por_categoria: Vec<Contagem>,
    pub por_status: Vec<Contagem>,
    pub por_gravidade: Vec<Contagem>,
    pub por_dia: Vec<Contagem>,
    pub por_bairro: Vec<Contagem>,
    pub por_cidade: Vec<Contagem>,
    pub mais_confirmados: Vec<Relato>,
    pub gerado_em: String,
}

async fn contar(state: &AppState, sql: &str) -> ApiResult<i64> {
    Ok(sqlx::query_scalar::<_, i64>(sql).fetch_one(&state.pool).await?)
}

async fn agrupar(state: &AppState, sql: &str) -> ApiResult<Vec<Contagem>> {
    Ok(sqlx::query_as::<_, Contagem>(sql).fetch_all(&state.pool).await?)
}

pub async fn estatisticas(State(state): State<AppState>) -> ApiResult<Json<Estatisticas>> {
    let total_relatos = contar(&state, "SELECT COUNT(*) FROM relatos").await?;
    let abertos = contar(&state, "SELECT COUNT(*) FROM relatos WHERE status = 'aberto'").await?;
    let em_analise = contar(&state, "SELECT COUNT(*) FROM relatos WHERE status = 'em_analise'").await?;
    let resolvidos = contar(&state, "SELECT COUNT(*) FROM relatos WHERE status = 'resolvido'").await?;
    let invalidos = contar(&state, "SELECT COUNT(*) FROM relatos WHERE status = 'invalido'").await?;

    let ha_7d = (chrono::Utc::now() - chrono::Duration::days(7)).to_rfc3339_opts(chrono::SecondsFormat::Secs, true);
    let ha_24h = (chrono::Utc::now() - chrono::Duration::hours(24)).to_rfc3339_opts(chrono::SecondsFormat::Secs, true);
    let ultimos_7_dias = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM relatos WHERE criado_em >= ?")
        .bind(&ha_7d)
        .fetch_one(&state.pool)
        .await?;
    let ultimas_24h = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM relatos WHERE criado_em >= ?")
        .bind(&ha_24h)
        .fetch_one(&state.pool)
        .await?;

    let total_usuarios = contar(&state, "SELECT COUNT(*) FROM usuarios").await?;
    let total_confirmacoes = contar(&state, "SELECT COUNT(*) FROM confirmacoes").await?;
    let total_comentarios = contar(&state, "SELECT COUNT(*) FROM comentarios").await?;
    let total_amostras_ar = contar(&state, "SELECT COUNT(*) FROM amostras_ar").await?;

    let validos = total_relatos - invalidos;
    let taxa_resolucao_pct = if validos > 0 { resolvidos as f64 * 100.0 / validos as f64 } else { 0.0 };
    let tempo_medio_resolucao_horas = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT AVG((julianday(resolvido_em) - julianday(criado_em)) * 24.0) FROM relatos WHERE resolvido_em IS NOT NULL",
    )
    .fetch_one(&state.pool)
    .await?;
    let gravidade_media = sqlx::query_scalar::<_, Option<f64>>("SELECT AVG(gravidade) FROM relatos")
        .fetch_one(&state.pool)
        .await?;

    let mut por_categoria = agrupar(&state, "SELECT categoria AS nome, COUNT(*) AS total FROM relatos GROUP BY categoria ORDER BY total DESC").await?;
    for (id, _, _, _) in CATEGORIAS {
        if !por_categoria.iter().any(|c| c.nome == *id) {
            por_categoria.push(Contagem { nome: id.to_string(), total: 0 });
        }
    }
    let por_status = agrupar(&state, "SELECT status AS nome, COUNT(*) AS total FROM relatos GROUP BY status ORDER BY total DESC").await?;
    let por_gravidade = agrupar(&state, "SELECT CAST(gravidade AS TEXT) AS nome, COUNT(*) AS total FROM relatos GROUP BY gravidade ORDER BY gravidade").await?;
    let por_bairro = agrupar(&state, "SELECT bairro AS nome, COUNT(*) AS total FROM relatos WHERE bairro IS NOT NULL AND bairro <> '' GROUP BY bairro ORDER BY total DESC LIMIT 10").await?;
    let por_cidade = agrupar(&state, "SELECT cidade AS nome, COUNT(*) AS total FROM relatos WHERE cidade IS NOT NULL AND cidade <> '' GROUP BY cidade ORDER BY total DESC LIMIT 10").await?;

    let inicio = chrono::Utc::now().date_naive() - chrono::Duration::days(29);
    let brutos = sqlx::query_as::<_, Contagem>(
        "SELECT substr(criado_em, 1, 10) AS nome, COUNT(*) AS total FROM relatos WHERE criado_em >= ? GROUP BY nome ORDER BY nome",
    )
    .bind(inicio.format("%Y-%m-%dT00:00:00Z").to_string())
    .fetch_all(&state.pool)
    .await?;
    let por_dia = (0..30)
        .map(|i| {
            let dia = (inicio + chrono::Duration::days(i)).format("%Y-%m-%d").to_string();
            let total = brutos.iter().find(|c| c.nome == dia).map(|c| c.total).unwrap_or(0);
            Contagem { nome: dia, total }
        })
        .collect();

    let mais_confirmados = sqlx::query_as::<_, Relato>(&format!(
        "{BASE_SELECT} WHERE r.status <> 'invalido' ORDER BY r.confirmacoes DESC, r.gravidade DESC LIMIT 5"
    ))
    .fetch_all(&state.pool)
    .await?;

    Ok(Json(Estatisticas {
        total_relatos,
        abertos,
        em_analise,
        resolvidos,
        invalidos,
        ultimos_7_dias,
        ultimas_24h,
        total_usuarios,
        total_confirmacoes,
        total_comentarios,
        total_amostras_ar,
        taxa_resolucao_pct,
        tempo_medio_resolucao_horas,
        gravidade_media,
        por_categoria,
        por_status,
        por_gravidade,
        por_dia,
        por_bairro,
        por_cidade,
        mais_confirmados,
        gerado_em: agora(),
    }))
}

fn campo_csv(v: &str) -> String {
    format!("\"{}\"", v.replace('"', "\"\""))
}

pub async fn exportar_csv(State(state): State<AppState>) -> ApiResult<([(axum::http::HeaderName, String); 2], String)> {
    let lista = sqlx::query_as::<_, Relato>(&format!("{BASE_SELECT} ORDER BY r.criado_em DESC"))
        .fetch_all(&state.pool)
        .await?;
    let mut csv = String::from("\u{FEFF}");
    csv.push_str("id;categoria;titulo;descricao;gravidade;status;bairro;cidade;endereco;latitude;longitude;confirmacoes;comentarios;autor;criado_em;resolvido_em\n");
    for r in lista {
        let linha = [
            r.id.to_string(),
            campo_csv(&r.categoria),
            campo_csv(&r.titulo),
            campo_csv(&r.descricao),
            r.gravidade.to_string(),
            campo_csv(&r.status),
            campo_csv(r.bairro.as_deref().unwrap_or("")),
            campo_csv(r.cidade.as_deref().unwrap_or("")),
            campo_csv(r.endereco.as_deref().unwrap_or("")),
            format!("{:.6}", r.latitude).replace('.', ","),
            format!("{:.6}", r.longitude).replace('.', ","),
            r.confirmacoes.to_string(),
            r.comentarios_qtd.to_string(),
            campo_csv(&r.autor_nome),
            campo_csv(&r.criado_em),
            campo_csv(r.resolvido_em.as_deref().unwrap_or("")),
        ];
        csv.push_str(&linha.join(";"));
        csv.push('\n');
    }
    let nome = format!("attachment; filename=\"ecoalerta-relatos-{}.csv\"", chrono::Utc::now().format("%Y%m%d-%H%M"));
    Ok(([(CONTENT_TYPE, "text/csv; charset=utf-8".to_string()), (CONTENT_DISPOSITION, nome)], csv))
}
