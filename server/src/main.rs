mod auth;
mod coletor;
mod db;
mod erros;
mod externo;
mod modelos;
mod rotas;
mod seed;

use std::{
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, AtomicUsize, Ordering},
        Arc, Mutex,
    },
    time::Instant,
};

use axum::{
    extract::{DefaultBodyLimit, Request, State},
    middleware::{self, Next},
    response::{Html, IntoResponse, Response},
    routing::{get, patch, post},
    Json, Router,
};
use serde_json::json;
use sqlx::SqlitePool;
use tokio::sync::broadcast;
use tower_http::{cors::CorsLayer, services::ServeDir, trace::TraceLayer};

use crate::modelos::agora;

pub const VERSAO: &str = env!("CARGO_PKG_VERSION");

#[derive(Clone)]
pub struct AppState {
    pub pool: SqlitePool,
    pub jwt_secret: String,
    pub tx: broadcast::Sender<String>,
    pub externo: Arc<externo::Externo>,
    pub inicio: Instant,
    pub uploads_dir: PathBuf,
    pub clientes_ws: Arc<AtomicUsize>,
    pub eventos_emitidos: Arc<AtomicU64>,
    pub requisicoes: Arc<AtomicU64>,
    pub ultima_coleta: Arc<Mutex<Option<String>>>,
}

impl AppState {
    pub fn emitir(&self, tipo: &str, dados: serde_json::Value) {
        let msg = json!({ "tipo": tipo, "hora": agora(), "dados": dados }).to_string();
        self.eventos_emitidos.fetch_add(1, Ordering::Relaxed);
        let _ = self.tx.send(msg);
    }
}

fn env_ou(nome: &str, padrao: &str) -> String {
    std::env::var(nome).unwrap_or_else(|_| padrao.to_string())
}

fn ip_local() -> Option<String> {
    let s = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    s.connect("8.8.8.8:80").ok()?;
    s.local_addr().ok().map(|a| a.ip().to_string())
}

async fn contar_requisicoes(State(state): State<AppState>, req: Request, next: Next) -> Response {
    state.requisicoes.fetch_add(1, Ordering::Relaxed);
    next.run(req).await
}

async fn health(State(state): State<AppState>) -> Json<serde_json::Value> {
    let ultima_coleta = state.ultima_coleta.lock().ok().and_then(|u| u.clone());
    Json(json!({
        "status": "ok",
        "servico": "EcoAlerta API",
        "versao": VERSAO,
        "hora_servidor": agora(),
        "uptime_segundos": state.inicio.elapsed().as_secs(),
        "clientes_websocket": state.clientes_ws.load(Ordering::Relaxed),
        "eventos_emitidos": state.eventos_emitidos.load(Ordering::Relaxed),
        "requisicoes_atendidas": state.requisicoes.load(Ordering::Relaxed),
        "consultas_externas": state.externo.consultas_externas.load(Ordering::Relaxed),
        "acertos_cache": state.externo.acertos_cache.load(Ordering::Relaxed),
        "itens_cache": state.externo.cache_ar.tamanho() + state.externo.cache_clima.tamanho() + state.externo.cache_geo.tamanho(),
        "ultima_coleta_ar": ultima_coleta,
        "banco": "SQLite (WAL)",
    }))
}

async fn painel() -> impl IntoResponse {
    Html(include_str!("../static/painel.html"))
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=info,sqlx=warn".into()),
        )
        .init();

    let porta: u16 = env_ou("PORTA", "8080").parse().unwrap_or(8080);
    let banco = env_ou("BANCO", "ecoalerta.db");
    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| {
        tracing::warn!("JWT_SECRET não definido; usando segredo de desenvolvimento");
        "ecoalerta-segredo-de-desenvolvimento-troque-em-producao".to_string()
    });
    let coleta_minutos: u64 = env_ou("COLETA_MINUTOS", "30").parse().unwrap_or(30);
    let uploads_dir = PathBuf::from(env_ou("UPLOADS", "uploads"));
    std::fs::create_dir_all(&uploads_dir)?;

    let pool = db::conectar(&banco).await?;
    let semeado = seed::semear_se_vazio(&pool).await?;

    let (tx, _rx) = broadcast::channel::<String>(256);
    let state = AppState {
        pool,
        jwt_secret,
        tx,
        externo: Arc::new(externo::Externo::novo()),
        inicio: Instant::now(),
        uploads_dir: uploads_dir.clone(),
        clientes_ws: Arc::new(AtomicUsize::new(0)),
        eventos_emitidos: Arc::new(AtomicU64::new(0)),
        requisicoes: Arc::new(AtomicU64::new(0)),
        ultima_coleta: Arc::new(Mutex::new(None)),
    };

    coletor::iniciar(state.clone(), coleta_minutos);

    let app = Router::new()
        .route("/", get(painel))
        .route("/api/health", get(health))
        .route("/api/auth/registrar", post(rotas::auth::registrar))
        .route("/api/auth/login", post(rotas::auth::login))
        .route("/api/auth/eu", get(rotas::auth::eu))
        .route("/api/categorias", get(rotas::relatos::categorias))
        .route("/api/relatos", get(rotas::relatos::listar).post(rotas::relatos::criar))
        .route("/api/relatos/{id}", get(rotas::relatos::obter).delete(rotas::relatos::excluir))
        .route("/api/relatos/{id}/confirmar", post(rotas::relatos::confirmar))
        .route("/api/relatos/{id}/status", patch(rotas::relatos::alterar_status))
        .route("/api/relatos/{id}/historico", get(rotas::relatos::historico))
        .route(
            "/api/relatos/{id}/comentarios",
            get(rotas::relatos::listar_comentarios).post(rotas::relatos::comentar),
        )
        .route("/api/ambiente/ar", get(rotas::ambiente::ar))
        .route("/api/ambiente/clima", get(rotas::ambiente::clima))
        .route("/api/ambiente/pontos", get(rotas::ambiente::pontos))
        .route("/api/ambiente/historico", get(rotas::ambiente::historico))
        .route("/api/ambiente/coletar", post(rotas::ambiente::coletar_agora))
        .route("/api/geocode/reverso", get(rotas::ambiente::geocode))
        .route("/api/estatisticas", get(rotas::estatisticas::estatisticas))
        .route("/api/relatorios/relatos.csv", get(rotas::estatisticas::exportar_csv))
        .route("/ws", get(rotas::ws::ws_handler))
        .nest_service("/uploads", ServeDir::new(&uploads_dir))
        .layer(middleware::from_fn_with_state(state.clone(), contar_requisicoes))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .layer(DefaultBodyLimit::max(12 * 1024 * 1024))
        .with_state(state);

    let endereco = format!("0.0.0.0:{porta}");
    let listener = tokio::net::TcpListener::bind(&endereco).await?;
    println!("==============================================================");
    println!("  EcoAlerta API v{VERSAO}  -  sistema distribuído (APS DSD)");
    println!("  Banco: {banco}   Uploads: {}   Seed: {}", uploads_dir.display(), if semeado { "inserido" } else { "já existia" });
    println!("  Painel web:  http://localhost:{porta}/");
    println!("  Emulador:    http://10.0.2.2:{porta}");
    if let Some(ip) = ip_local() {
        println!("  Celular:     http://{ip}:{porta}  (mesma rede Wi-Fi)");
    }
    println!("  WebSocket:   ws://localhost:{porta}/ws");
    println!("  Login demo:  gestor@ecoalerta.app / gestor123   |   ana@ecoalerta.app / 123456");
    println!("==============================================================");
    axum::serve(listener, app).await?;
    Ok(())
}
