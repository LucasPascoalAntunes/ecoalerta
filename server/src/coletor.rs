use std::time::Duration;

use crate::{
    externo,
    modelos::{agora, PontoMonitorado},
    AppState,
};

pub fn iniciar(state: AppState, intervalo_min: u64) {
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_secs(5)).await;
        loop {
            match coletar(&state).await {
                Ok(n) => tracing::info!(pontos = n, "coleta periódica de qualidade do ar concluída"),
                Err(e) => tracing::warn!(erro = %e, "coleta periódica falhou"),
            }
            tokio::time::sleep(Duration::from_secs(intervalo_min.max(1) * 60)).await;
        }
    });
}

pub async fn coletar(state: &AppState) -> anyhow::Result<usize> {
    let pontos = sqlx::query_as::<_, PontoMonitorado>(
        "SELECT id, nome, latitude, longitude FROM pontos_monitorados ORDER BY id",
    )
    .fetch_all(&state.pool)
    .await?;

    let mut ok = 0usize;
    for p in pontos {
        match externo::qualidade_ar(&state.externo, p.latitude, p.longitude).await {
            Ok(q) => {
                sqlx::query(
                    "INSERT INTO amostras_ar (ponto_id, aqi_eu, pm2_5, pm10, no2, o3, coletado_em) VALUES (?, ?, ?, ?, ?, ?, ?)",
                )
                .bind(p.id)
                .bind(q.aqi_eu)
                .bind(q.pm2_5)
                .bind(q.pm10)
                .bind(q.no2)
                .bind(q.o3)
                .bind(agora())
                .execute(&state.pool)
                .await?;
                ok += 1;
                state.emitir(
                    "amostra_ar",
                    serde_json::json!({
                        "ponto_id": p.id,
                        "ponto": p.nome,
                        "aqi_eu": q.aqi_eu,
                        "pm2_5": q.pm2_5,
                        "classificacao": q.classificacao,
                        "cor": q.cor,
                    }),
                );
            }
            Err(e) => tracing::warn!(ponto = %p.nome, erro = ?e, "não foi possível coletar qualidade do ar"),
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
    if let Ok(mut u) = state.ultima_coleta.lock() {
        *u = Some(agora());
    }
    Ok(ok)
}
