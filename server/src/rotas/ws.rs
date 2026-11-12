use std::sync::atomic::Ordering;

use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::IntoResponse,
};
use futures::{SinkExt, StreamExt};
use tokio::sync::broadcast::error::RecvError;

use crate::{modelos::agora, AppState};

pub async fn ws_handler(ws: WebSocketUpgrade, State(state): State<AppState>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| tratar(socket, state))
}

async fn tratar(socket: WebSocket, state: AppState) {
    let (mut envio, mut recepcao) = socket.split();
    let mut rx = state.tx.subscribe();
    let conectados = state.clientes_ws.fetch_add(1, Ordering::Relaxed) + 1;
    tracing::info!(conectados, "cliente WebSocket conectado");

    let boas_vindas = serde_json::json!({
        "tipo": "conectado",
        "hora": agora(),
        "dados": { "clientes": conectados, "mensagem": "Conectado ao EcoAlerta em tempo real" }
    })
    .to_string();
    if envio.send(Message::Text(boas_vindas.into())).await.is_err() {
        state.clientes_ws.fetch_sub(1, Ordering::Relaxed);
        return;
    }

    let mut tarefa_envio = tokio::spawn(async move {
        loop {
            match rx.recv().await {
                Ok(msg) => {
                    if envio.send(Message::Text(msg.into())).await.is_err() {
                        break;
                    }
                }
                Err(RecvError::Lagged(n)) => {
                    tracing::warn!(perdidas = n, "cliente WebSocket lento, mensagens descartadas");
                }
                Err(RecvError::Closed) => break,
            }
        }
    });

    let mut tarefa_recepcao = tokio::spawn(async move {
        while let Some(Ok(msg)) = recepcao.next().await {
            if let Message::Close(_) = msg {
                break;
            }
        }
    });

    tokio::select! {
        _ = &mut tarefa_envio => tarefa_recepcao.abort(),
        _ = &mut tarefa_recepcao => tarefa_envio.abort(),
    }
    let restantes = state.clientes_ws.fetch_sub(1, Ordering::Relaxed) - 1;
    tracing::info!(conectados = restantes, "cliente WebSocket desconectado");
}
