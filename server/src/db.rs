use std::{str::FromStr, time::Duration};

use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
    SqlitePool,
};

const ESQUEMA: &str = r#"
CREATE TABLE IF NOT EXISTS usuarios (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    senha_hash  TEXT NOT NULL,
    papel       TEXT NOT NULL DEFAULT 'cidadao',
    criado_em   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS relatos (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id    INTEGER NOT NULL REFERENCES usuarios(id),
    categoria     TEXT NOT NULL,
    titulo        TEXT NOT NULL,
    descricao     TEXT NOT NULL,
    gravidade     INTEGER NOT NULL DEFAULT 3,
    status        TEXT NOT NULL DEFAULT 'aberto',
    latitude      REAL NOT NULL,
    longitude     REAL NOT NULL,
    endereco      TEXT,
    bairro        TEXT,
    cidade        TEXT,
    foto_url      TEXT,
    confirmacoes  INTEGER NOT NULL DEFAULT 0,
    criado_em     TEXT NOT NULL,
    atualizado_em TEXT NOT NULL,
    resolvido_em  TEXT
);
CREATE INDEX IF NOT EXISTS idx_relatos_criado ON relatos(criado_em);
CREATE INDEX IF NOT EXISTS idx_relatos_categoria ON relatos(categoria);
CREATE INDEX IF NOT EXISTS idx_relatos_status ON relatos(status);

CREATE TABLE IF NOT EXISTS confirmacoes (
    relato_id  INTEGER NOT NULL REFERENCES relatos(id) ON DELETE CASCADE,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    criado_em  TEXT NOT NULL,
    PRIMARY KEY (relato_id, usuario_id)
);

CREATE TABLE IF NOT EXISTS comentarios (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    relato_id  INTEGER NOT NULL REFERENCES relatos(id) ON DELETE CASCADE,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    texto      TEXT NOT NULL,
    criado_em  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS historico_status (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    relato_id   INTEGER NOT NULL REFERENCES relatos(id) ON DELETE CASCADE,
    usuario_id  INTEGER NOT NULL REFERENCES usuarios(id),
    de_status   TEXT NOT NULL,
    para_status TEXT NOT NULL,
    observacao  TEXT,
    criado_em   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pontos_monitorados (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    nome      TEXT NOT NULL,
    latitude  REAL NOT NULL,
    longitude REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS amostras_ar (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ponto_id    INTEGER NOT NULL REFERENCES pontos_monitorados(id),
    aqi_eu      REAL,
    pm2_5       REAL,
    pm10        REAL,
    no2         REAL,
    o3          REAL,
    coletado_em TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_amostras_ponto ON amostras_ar(ponto_id, coletado_em);
"#;

pub async fn conectar(caminho: &str) -> anyhow::Result<SqlitePool> {
    let opcoes = SqliteConnectOptions::from_str(&format!("sqlite://{caminho}"))?
        .create_if_missing(true)
        .journal_mode(SqliteJournalMode::Wal)
        .busy_timeout(Duration::from_secs(5))
        .foreign_keys(true);

    let pool = SqlitePoolOptions::new()
        .max_connections(8)
        .connect_with(opcoes)
        .await?;

    sqlx::raw_sql(ESQUEMA).execute(&pool).await?;
    Ok(pool)
}
