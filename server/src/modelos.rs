use serde::{Deserialize, Serialize};
use sqlx::FromRow;

pub const CATEGORIAS: &[(&str, &str, &str, &str)] = &[
    ("alagamento", "Alagamento / inundação", "water", "Ruas, avenidas ou imóveis tomados pela água"),
    ("poluicao_ar", "Poluição do ar", "factory", "Fumaça, fuligem, odor químico ou ar carregado"),
    ("descarte_irregular", "Descarte irregular", "delete", "Lixo, entulho ou resíduos em local impróprio"),
    ("desmatamento", "Desmatamento", "forest", "Corte ou supressão de vegetação e árvores"),
    ("queimada", "Queimada / incêndio", "fire", "Fogo em vegetação, terreno ou lixo"),
    ("invasao_manancial", "Invasão de manancial", "house", "Ocupação irregular em área de proteção de água"),
    ("transito", "Trânsito / transporte público", "bus", "Congestionamento crítico ou falha no transporte"),
    ("inversao_termica", "Inversão térmica", "fog", "Ar parado, névoa seca e poluição concentrada"),
    ("poluicao_sonora", "Poluição sonora", "volume", "Ruído excessivo e persistente"),
    ("poluicao_agua", "Poluição de rio / córrego", "science", "Esgoto, óleo ou espuma em corpo d'água"),
    ("outro", "Outro problema ambiental", "warning", "Ocorrência que não se encaixa nas demais"),
];

pub const STATUS: &[&str] = &["aberto", "em_analise", "resolvido", "invalido"];

pub fn categoria_valida(id: &str) -> bool {
    CATEGORIAS.iter().any(|(c, _, _, _)| *c == id)
}

pub fn agora() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
}

pub fn distancia_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let r = 6371.0_f64;
    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();
    let a = (dlat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    2.0 * r * a.sqrt().atan2((1.0 - a).sqrt())
}

#[derive(Debug, Clone, Serialize, FromRow)]
pub struct Usuario {
    pub id: i64,
    pub nome: String,
    pub email: String,
    pub papel: String,
    pub criado_em: String,
}

#[derive(Debug, Clone, Serialize, FromRow)]
pub struct Relato {
    pub id: i64,
    pub usuario_id: i64,
    pub autor_nome: String,
    pub categoria: String,
    pub titulo: String,
    pub descricao: String,
    pub gravidade: i64,
    pub status: String,
    pub latitude: f64,
    pub longitude: f64,
    pub endereco: Option<String>,
    pub bairro: Option<String>,
    pub cidade: Option<String>,
    pub foto_url: Option<String>,
    pub confirmacoes: i64,
    pub comentarios_qtd: i64,
    pub criado_em: String,
    pub atualizado_em: String,
    pub resolvido_em: Option<String>,
    #[sqlx(default)]
    pub distancia_km: Option<f64>,
    #[sqlx(default)]
    pub confirmado_por_mim: bool,
}

#[derive(Debug, Clone, Serialize, FromRow)]
pub struct Comentario {
    pub id: i64,
    pub relato_id: i64,
    pub usuario_id: i64,
    pub autor_nome: String,
    pub texto: String,
    pub criado_em: String,
}

#[derive(Debug, Clone, Serialize, FromRow)]
pub struct HistoricoStatus {
    pub id: i64,
    pub relato_id: i64,
    pub autor_nome: String,
    pub de_status: String,
    pub para_status: String,
    pub observacao: Option<String>,
    pub criado_em: String,
}

#[derive(Debug, Clone, Serialize, FromRow)]
pub struct PontoMonitorado {
    pub id: i64,
    pub nome: String,
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Debug, Clone, Serialize, FromRow)]
pub struct AmostraAr {
    pub id: i64,
    pub ponto_id: i64,
    pub aqi_eu: Option<f64>,
    pub pm2_5: Option<f64>,
    pub pm10: Option<f64>,
    pub no2: Option<f64>,
    pub o3: Option<f64>,
    pub coletado_em: String,
}

#[derive(Debug, Deserialize)]
pub struct RegistrarReq {
    pub nome: String,
    pub email: String,
    pub senha: String,
}

#[derive(Debug, Deserialize)]
pub struct LoginReq {
    pub email: String,
    pub senha: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResp {
    pub token: String,
    pub usuario: Usuario,
}

#[derive(Debug, Deserialize)]
pub struct NovoRelatoReq {
    pub categoria: String,
    pub titulo: String,
    pub descricao: String,
    pub gravidade: i64,
    pub latitude: f64,
    pub longitude: f64,
    pub endereco: Option<String>,
    pub bairro: Option<String>,
    pub cidade: Option<String>,
    pub foto_base64: Option<String>,
    pub criado_offline_em: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct FiltroRelatos {
    pub categoria: Option<String>,
    pub status: Option<String>,
    pub busca: Option<String>,
    pub lat: Option<f64>,
    pub lon: Option<f64>,
    pub raio_km: Option<f64>,
    pub ordenar: Option<String>,
    pub limite: Option<i64>,
    pub meus: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct AlterarStatusReq {
    pub status: String,
    pub observacao: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct NovoComentarioReq {
    pub texto: String,
}

#[derive(Debug, Deserialize)]
pub struct CoordQuery {
    pub lat: f64,
    pub lon: f64,
}

#[derive(Debug, Deserialize)]
pub struct HistoricoQuery {
    pub ponto_id: Option<i64>,
    pub lat: Option<f64>,
    pub lon: Option<f64>,
    pub horas: Option<i64>,
}
