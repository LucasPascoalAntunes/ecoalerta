use sqlx::SqlitePool;

use crate::{auth::hash_senha, modelos::agora};

struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }
    fn f(&mut self) -> f64 {
        (self.next() % 10_000) as f64 / 10_000.0
    }
    fn entre(&mut self, a: i64, b: i64) -> i64 {
        a + (self.next() % ((b - a + 1) as u64)) as i64
    }
}

struct RelatoSeed {
    categoria: &'static str,
    titulo: &'static str,
    descricao: &'static str,
    gravidade: i64,
    bairro: &'static str,
    endereco: &'static str,
    lat: f64,
    lon: f64,
}

const RELATOS: &[RelatoSeed] = &[
    RelatoSeed { categoria: "alagamento", titulo: "Av. Aricanduva tomada pela água", descricao: "Chuva forte no fim da tarde alagou as duas pistas próximo ao shopping. Carros ilhados e ônibus parados.", gravidade: 5, bairro: "Aricanduva", endereco: "Av. Aricanduva, 5555", lat: -23.5560, lon: -46.5350 },
    RelatoSeed { categoria: "alagamento", titulo: "Vale do Anhangabaú com bolsão de água", descricao: "Bueiros entupidos formaram bolsão de água de 40 cm na saída do túnel.", gravidade: 4, bairro: "Centro", endereco: "Vale do Anhangabaú, s/n", lat: -23.5450, lon: -46.6380 },
    RelatoSeed { categoria: "alagamento", titulo: "Córrego transbordou na Vila Prudente", descricao: "Córrego da Mooca subiu e invadiu garagens na rua paralela.", gravidade: 4, bairro: "Vila Prudente", endereco: "Rua Ibitirama, 120", lat: -23.5830, lon: -46.5800 },
    RelatoSeed { categoria: "alagamento", titulo: "Ponto de ônibus inacessível", descricao: "Água acumulada na calçada impede embarque no ponto em frente à escola.", gravidade: 2, bairro: "Jabaquara", endereco: "Av. Engenheiro Armando de Arruda Pereira, 2000", lat: -23.6460, lon: -46.6410 },
    RelatoSeed { categoria: "poluicao_ar", titulo: "Fumaça preta de fábrica", descricao: "Chaminé soltando fumaça escura desde as 7h, cheiro forte de queimado nas casas vizinhas.", gravidade: 4, bairro: "Mooca", endereco: "Rua Borges de Figueiredo, 400", lat: -23.5566, lon: -46.5977 },
    RelatoSeed { categoria: "poluicao_ar", titulo: "Ar carregado na Marginal", descricao: "Névoa acinzentada visível sobre a Marginal Tietê no início da manhã, ardência nos olhos.", gravidade: 3, bairro: "Santana", endereco: "Marginal Tietê, próximo à Ponte das Bandeiras", lat: -23.5180, lon: -46.6300 },
    RelatoSeed { categoria: "poluicao_ar", titulo: "Ônibus soltando fumaça excessiva", descricao: "Linha 8000-10 com escapamento soltando fumaça preta em toda a Av. Paulista.", gravidade: 2, bairro: "Bela Vista", endereco: "Av. Paulista, 1500", lat: -23.5614, lon: -46.6558 },
    RelatoSeed { categoria: "descarte_irregular", titulo: "Entulho de obra na calçada", descricao: "Caçamba virada e restos de construção ocupando toda a calçada e parte da rua há três dias.", gravidade: 3, bairro: "Pinheiros", endereco: "Rua dos Pinheiros, 800", lat: -23.5617, lon: -46.6820 },
    RelatoSeed { categoria: "descarte_irregular", titulo: "Lixo acumulado embaixo do viaduto", descricao: "Sofás, pneus e sacos de lixo acumulados. Já tem rato e mau cheiro.", gravidade: 4, bairro: "Lapa", endereco: "Viaduto Antártica", lat: -23.5270, lon: -46.7010 },
    RelatoSeed { categoria: "descarte_irregular", titulo: "Ponto viciado de lixo em terreno baldio", descricao: "Terreno recebe descarte toda noite. Moradores pedem ecoponto na região.", gravidade: 3, bairro: "Itaquera", endereco: "Rua Virgínia Ferni, 300", lat: -23.5390, lon: -46.4550 },
    RelatoSeed { categoria: "descarte_irregular", titulo: "Óleo de cozinha jogado na sarjeta", descricao: "Restaurante despeja óleo na rua todas as madrugadas.", gravidade: 2, bairro: "Tatuapé", endereco: "Rua Tuiuti, 2100", lat: -23.5400, lon: -46.5760 },
    RelatoSeed { categoria: "desmatamento", titulo: "Corte de árvores na Cantareira", descricao: "Máquinas derrubando vegetação nativa em área de borda do parque, sem placa de licença.", gravidade: 5, bairro: "Tremembé", endereco: "Estrada da Cantareira, km 8", lat: -23.4300, lon: -46.6300 },
    RelatoSeed { categoria: "desmatamento", titulo: "Árvores centenárias removidas para estacionamento", descricao: "Cinco árvores de grande porte cortadas de madrugada em terreno comercial.", gravidade: 3, bairro: "Butantã", endereco: "Av. Corifeu de Azevedo Marques, 1200", lat: -23.5710, lon: -46.7190 },
    RelatoSeed { categoria: "queimada", titulo: "Fogo em terreno próximo a casas", descricao: "Queimada de lixo se espalhou pelo mato seco; fumaça densa entrando nas residências.", gravidade: 4, bairro: "Capão Redondo", endereco: "Estrada de Itapecerica, 4500", lat: -23.6670, lon: -46.7750 },
    RelatoSeed { categoria: "queimada", titulo: "Incêndio em área verde", descricao: "Fogo em vegetação às margens da rodovia, bombeiros acionados.", gravidade: 5, bairro: "Cidade Tiradentes", endereco: "Av. dos Metalúrgicos, 3000", lat: -23.5890, lon: -46.4040 },
    RelatoSeed { categoria: "invasao_manancial", titulo: "Novas construções na represa Guarapiranga", descricao: "Barracos sendo erguidos a menos de 30 m da margem, com esgoto direto na represa.", gravidade: 5, bairro: "Parelheiros", endereco: "Estrada da Colônia, km 5", lat: -23.8270, lon: -46.7290 },
    RelatoSeed { categoria: "invasao_manancial", titulo: "Loteamento irregular em área de proteção", descricao: "Placas de venda de lotes em área de mananciais da Billings.", gravidade: 4, bairro: "Marsilac", endereco: "Estrada Evangelista de Souza, s/n", lat: -23.9000, lon: -46.7050 },
    RelatoSeed { categoria: "invasao_manancial", titulo: "Aterro na margem da represa", descricao: "Caminhões despejando terra na beira da água para ampliar terreno.", gravidade: 4, bairro: "Interlagos", endereco: "Av. Robert Kennedy, 3300", lat: -23.6950, lon: -46.6870 },
    RelatoSeed { categoria: "transito", titulo: "Marginal parada há 2 horas", descricao: "Acidente com caminhão interditou três faixas; ônibus da linha 9000 atrasados 50 minutos.", gravidade: 4, bairro: "Barra Funda", endereco: "Marginal Tietê, pista expressa", lat: -23.5180, lon: -46.6600 },
    RelatoSeed { categoria: "transito", titulo: "Semáforo apagado em cruzamento crítico", descricao: "Semáforo sem funcionar desde a manhã, filas de 1 km.", gravidade: 3, bairro: "Vila Mariana", endereco: "Av. Domingos de Morais x Rua Vergueiro", lat: -23.5890, lon: -46.6340 },
    RelatoSeed { categoria: "transito", titulo: "Terminal lotado e sem ônibus", descricao: "Passageiros esperando mais de 40 minutos no terminal, veículos circulando lotados.", gravidade: 3, bairro: "Penha", endereco: "Terminal Penha", lat: -23.5280, lon: -46.5410 },
    RelatoSeed { categoria: "inversao_termica", titulo: "Névoa e ar parado sobre a região", descricao: "Camada cinza cobrindo o horizonte, dificuldade para respirar em idosos.", gravidade: 3, bairro: "Freguesia do Ó", endereco: "Av. Itaberaba, 900", lat: -23.4990, lon: -46.6980 },
    RelatoSeed { categoria: "inversao_termica", titulo: "Poluição concentrada no vale", descricao: "Manhã fria, sem vento, fumaça presa no vale do rio.", gravidade: 2, bairro: "Ipiranga", endereco: "Rua Bom Pastor, 500", lat: -23.5875, lon: -46.6100 },
    RelatoSeed { categoria: "poluicao_sonora", titulo: "Obra noturna com britadeira", descricao: "Obra funcionando até 2h da manhã com ruído acima do permitido.", gravidade: 2, bairro: "Brooklin", endereco: "Rua Joaquim Nabuco, 300", lat: -23.6150, lon: -46.6870 },
    RelatoSeed { categoria: "poluicao_sonora", titulo: "Som automotivo em praça", descricao: "Carros com som alto toda sexta-feira até de madrugada.", gravidade: 2, bairro: "Santana", endereco: "Praça Campo de Bagatelle", lat: -23.5030, lon: -46.6250 },
    RelatoSeed { categoria: "poluicao_agua", titulo: "Espuma branca no Rio Pinheiros", descricao: "Grande quantidade de espuma e cheiro forte de esgoto próximo à ponte.", gravidade: 4, bairro: "Pinheiros", endereco: "Ponte Cidade Jardim", lat: -23.5950, lon: -46.6970 },
    RelatoSeed { categoria: "poluicao_agua", titulo: "Mancha de óleo no Tietê", descricao: "Mancha escura de aproximadamente 200 m acompanhando a correnteza.", gravidade: 4, bairro: "Bom Retiro", endereco: "Ponte da Casa Verde", lat: -23.5150, lon: -46.6200 },
    RelatoSeed { categoria: "poluicao_agua", titulo: "Esgoto a céu aberto em córrego", descricao: "Tubulação clandestina despejando esgoto no córrego que passa atrás do conjunto habitacional.", gravidade: 3, bairro: "Jabaquara", endereco: "Rua das Bandeiras, 40", lat: -23.6500, lon: -46.6380 },
    RelatoSeed { categoria: "outro", titulo: "Bueiro sem tampa", descricao: "Bueiro aberto na esquina, risco de queda e entrada de lixo na galeria.", gravidade: 3, bairro: "Sé", endereco: "Rua Direita, 100", lat: -23.5505, lon: -46.6333 },
    RelatoSeed { categoria: "alagamento", titulo: "Passagem subterrânea alagada", descricao: "Passagem de pedestres com 30 cm de água, pessoas atravessando a avenida por cima.", gravidade: 3, bairro: "Tatuapé", endereco: "Radial Leste, 3000", lat: -23.5420, lon: -46.5700 },
    RelatoSeed { categoria: "descarte_irregular", titulo: "Pneus abandonados junto ao córrego", descricao: "Mais de 50 pneus jogados na margem, foco de dengue.", gravidade: 3, bairro: "Itaquera", endereco: "Av. Itaquera, 4000", lat: -23.5450, lon: -46.4600 },
    RelatoSeed { categoria: "queimada", titulo: "Queima de lixo doméstico", descricao: "Vizinho queima lixo no quintal todos os dias no fim da tarde.", gravidade: 2, bairro: "Capão Redondo", endereco: "Rua Alberto Cochrane, 55", lat: -23.6600, lon: -46.7700 },
];

pub async fn semear_se_vazio(pool: &SqlitePool) -> anyhow::Result<bool> {
    let usuarios: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM usuarios").fetch_one(pool).await?;
    if usuarios > 0 {
        return Ok(false);
    }
    tracing::info!("banco vazio: inserindo dados de demonstração");
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15);
    let agora_txt = agora();

    let contas = [
        ("Gestora Ambiental", "gestor@ecoalerta.app", "gestor123", "gestor"),
        ("Ana Souza", "ana@ecoalerta.app", "123456", "cidadao"),
        ("Bruno Lima", "bruno@ecoalerta.app", "123456", "cidadao"),
        ("Carla Mendes", "carla@ecoalerta.app", "123456", "cidadao"),
    ];
    let mut ids = Vec::new();
    for (nome, email, senha, papel) in contas {
        let hash = hash_senha(senha).map_err(|e| anyhow::anyhow!("{e:?}"))?;
        let id = sqlx::query(
            "INSERT INTO usuarios (nome, email, senha_hash, papel, criado_em) VALUES (?, ?, ?, ?, ?)",
        )
        .bind(nome)
        .bind(email)
        .bind(hash)
        .bind(papel)
        .bind(&agora_txt)
        .execute(pool)
        .await?
        .last_insert_rowid();
        ids.push(id);
    }
    let cidadaos = &ids[1..];

    let pontos = [
        ("São Paulo - Centro (Sé)", -23.5505, -46.6333),
        ("São Paulo - Zona Leste (Itaquera)", -23.5390, -46.4550),
        ("Santos - Centro", -23.9608, -46.3336),
        ("Registro - Vale do Ribeira", -24.4875, -47.8436),
        ("Itariri", -24.2833, -47.1736),
        ("Peruíbe - Litoral Sul", -24.3200, -47.0000),
    ];
    for (nome, lat, lon) in pontos {
        sqlx::query("INSERT INTO pontos_monitorados (nome, latitude, longitude) VALUES (?, ?, ?)")
            .bind(nome)
            .bind(lat)
            .bind(lon)
            .execute(pool)
            .await?;
    }

    let agora_dt = chrono::Utc::now();
    let fmt = |d: chrono::DateTime<chrono::Utc>| d.to_rfc3339_opts(chrono::SecondsFormat::Secs, true);
    for (i, r) in RELATOS.iter().enumerate() {
        let autor = cidadaos[i % cidadaos.len()];
        let dias = rng.entre(0, 29);
        let horas = rng.entre(0, 23);
        let criado = agora_dt - chrono::Duration::days(dias) - chrono::Duration::hours(horas);
        let sorteio = rng.f();
        let status = if sorteio < 0.45 {
            "aberto"
        } else if sorteio < 0.70 {
            "em_analise"
        } else if sorteio < 0.94 {
            "resolvido"
        } else {
            "invalido"
        };
        let resolvido_em = if status == "resolvido" {
            let horas_res = rng.entre(6, 120);
            Some((criado + chrono::Duration::hours(horas_res)).min(agora_dt))
        } else {
            None
        };
        let atualizado = resolvido_em.unwrap_or(criado);
        let jitter_lat = (rng.f() - 0.5) * 0.006;
        let jitter_lon = (rng.f() - 0.5) * 0.006;

        let relato_id = sqlx::query(
            "INSERT INTO relatos (usuario_id, categoria, titulo, descricao, gravidade, status, latitude, longitude, endereco, bairro, cidade, confirmacoes, criado_em, atualizado_em, resolvido_em)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)",
        )
        .bind(autor)
        .bind(r.categoria)
        .bind(r.titulo)
        .bind(r.descricao)
        .bind(r.gravidade)
        .bind(status)
        .bind(r.lat + jitter_lat)
        .bind(r.lon + jitter_lon)
        .bind(r.endereco)
        .bind(r.bairro)
        .bind("São Paulo")
        .bind(fmt(criado))
        .bind(fmt(atualizado))
        .bind(resolvido_em.map(fmt))
        .execute(pool)
        .await?
        .last_insert_rowid();

        for c in cidadaos {
            if *c != autor && rng.f() < 0.5 {
                let quando = fmt(criado + chrono::Duration::hours(rng.entre(1, 48)));
                sqlx::query("INSERT OR IGNORE INTO confirmacoes (relato_id, usuario_id, criado_em) VALUES (?, ?, ?)")
                    .bind(relato_id)
                    .bind(c)
                    .bind(quando)
                    .execute(pool)
                    .await?;
            }
        }
        sqlx::query("UPDATE relatos SET confirmacoes = (SELECT COUNT(*) FROM confirmacoes WHERE relato_id = ?) WHERE id = ?")
            .bind(relato_id)
            .bind(relato_id)
            .execute(pool)
            .await?;

        if status != "aberto" {
            let observacao = match status {
                "em_analise" => "Equipe de fiscalização acionada.",
                "resolvido" => "Ocorrência atendida e encerrada.",
                _ => "Não foi possível confirmar a ocorrência no local.",
            };
            sqlx::query("INSERT INTO historico_status (relato_id, usuario_id, de_status, para_status, observacao, criado_em) VALUES (?, ?, 'aberto', ?, ?, ?)")
                .bind(relato_id)
                .bind(ids[0])
                .bind(status)
                .bind(observacao)
                .bind(fmt(atualizado))
                .execute(pool)
                .await?;
        }
        if rng.f() < 0.4 {
            let quando = fmt(criado + chrono::Duration::hours(rng.entre(2, 30)));
            sqlx::query("INSERT INTO comentarios (relato_id, usuario_id, texto, criado_em) VALUES (?, ?, ?, ?)")
                .bind(relato_id)
                .bind(cidadaos[(i + 1) % cidadaos.len()])
                .bind("Passei por aqui hoje e o problema continua. Alguém já acionou a prefeitura?")
                .bind(quando)
                .execute(pool)
                .await?;
        }
    }
    tracing::info!(relatos = RELATOS.len(), "dados de demonstração inseridos");
    Ok(true)
}
