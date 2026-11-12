use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex,
    },
    time::{Duration, Instant},
};

use serde::Serialize;
use serde_json::Value;

use crate::{erros::ApiError, modelos::agora};

const TTL_AR: Duration = Duration::from_secs(10 * 60);
const TTL_CLIMA: Duration = Duration::from_secs(10 * 60);
const TTL_GEO: Duration = Duration::from_secs(24 * 3600);

pub struct CacheTtl<T: Clone> {
    itens: Mutex<HashMap<String, (Instant, T)>>,
}

impl<T: Clone> CacheTtl<T> {
    pub fn novo() -> Self {
        Self { itens: Mutex::new(HashMap::new()) }
    }
    pub fn fresco(&self, chave: &str, ttl: Duration) -> Option<T> {
        let m = self.itens.lock().ok()?;
        m.get(chave).filter(|(t, _)| t.elapsed() < ttl).map(|(_, v)| v.clone())
    }
    pub fn qualquer(&self, chave: &str) -> Option<T> {
        self.itens.lock().ok()?.get(chave).map(|(_, v)| v.clone())
    }
    pub fn guardar(&self, chave: &str, v: T) {
        if let Ok(mut m) = self.itens.lock() {
            m.insert(chave.to_string(), (Instant::now(), v));
        }
    }
    pub fn tamanho(&self) -> usize {
        self.itens.lock().map(|m| m.len()).unwrap_or(0)
    }
}

pub struct Externo {
    pub http: reqwest::Client,
    pub cache_ar: CacheTtl<QualidadeAr>,
    pub cache_clima: CacheTtl<Clima>,
    pub cache_geo: CacheTtl<Endereco>,
    pub consultas_externas: AtomicU64,
    pub acertos_cache: AtomicU64,
}

impl Externo {
    pub fn novo() -> Self {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(12))
            .user_agent("EcoAlerta/1.0 (projeto academico APS UNIP DSD)")
            .build()
            .expect("cliente HTTP");
        Self {
            http,
            cache_ar: CacheTtl::novo(),
            cache_clima: CacheTtl::novo(),
            cache_geo: CacheTtl::novo(),
            consultas_externas: AtomicU64::new(0),
            acertos_cache: AtomicU64::new(0),
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct PontoHora {
    pub hora: String,
    pub pm2_5: Option<f64>,
    pub pm10: Option<f64>,
    pub aqi_eu: Option<f64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct QualidadeAr {
    pub latitude: f64,
    pub longitude: f64,
    pub aqi_eu: Option<f64>,
    pub aqi_us: Option<f64>,
    pub pm2_5: Option<f64>,
    pub pm10: Option<f64>,
    pub co: Option<f64>,
    pub no2: Option<f64>,
    pub so2: Option<f64>,
    pub o3: Option<f64>,
    pub classificacao: String,
    pub cor: String,
    pub recomendacao: String,
    pub poluente_dominante: String,
    pub horario: Vec<PontoHora>,
    pub atualizado_em: String,
    pub fonte: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Risco {
    pub nivel: String,
    pub explicacao: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ClimaHora {
    pub hora: String,
    pub temperatura: Option<f64>,
    pub precipitacao: Option<f64>,
    pub probabilidade: Option<f64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Clima {
    pub latitude: f64,
    pub longitude: f64,
    pub temperatura: Option<f64>,
    pub sensacao: Option<f64>,
    pub umidade: Option<f64>,
    pub precipitacao: Option<f64>,
    pub vento_kmh: Option<f64>,
    pub nebulosidade: Option<f64>,
    pub codigo_tempo: i64,
    pub descricao_tempo: String,
    pub eh_dia: bool,
    pub chuva_24h_mm: f64,
    pub prob_chuva_max: f64,
    pub temp_max: Option<f64>,
    pub temp_min: Option<f64>,
    pub risco_alagamento: Risco,
    pub risco_inversao_termica: Risco,
    pub horario: Vec<ClimaHora>,
    pub atualizado_em: String,
    pub fonte: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Endereco {
    pub endereco: String,
    pub rua: Option<String>,
    pub bairro: Option<String>,
    pub cidade: Option<String>,
    pub estado: Option<String>,
    pub fonte: String,
}

fn f(v: &Value, k: &str) -> Option<f64> {
    v.get(k).and_then(|x| x.as_f64())
}

fn arr<'a>(v: &'a Value, ponteiro: &str) -> Vec<&'a Value> {
    v.pointer(ponteiro).and_then(|x| x.as_array()).map(|a| a.iter().collect()).unwrap_or_default()
}

fn classificar_aqi(aqi: Option<f64>) -> (&'static str, &'static str, &'static str) {
    match aqi {
        None => ("Indisponível", "#9E9E9E", "Sem dados de qualidade do ar para este ponto no momento."),
        Some(a) if a <= 20.0 => ("Boa", "#2E7D32", "Ar limpo. Ótimo para atividades ao ar livre."),
        Some(a) if a <= 40.0 => ("Razoável", "#7CB342", "Qualidade aceitável. Pessoas muito sensíveis podem sentir leve desconforto."),
        Some(a) if a <= 60.0 => ("Moderada", "#F9A825", "Grupos sensíveis (asmáticos, idosos, crianças) devem reduzir esforço prolongado ao ar livre."),
        Some(a) if a <= 80.0 => ("Ruim", "#EF6C00", "Evite exercícios intensos ao ar livre. Mantenha janelas fechadas nos horários de pico."),
        Some(a) if a <= 100.0 => ("Muito ruim", "#C62828", "Toda a população pode sentir efeitos. Permaneça em ambientes fechados se possível."),
        Some(_) => ("Extremamente ruim", "#6A1B9A", "Alerta de saúde: evite qualquer exposição ao ar livre."),
    }
}

fn poluente_dominante(cur: &Value) -> String {
    let candidatos = [
        ("PM2.5", f(cur, "pm2_5").map(|v| v / 25.0)),
        ("PM10", f(cur, "pm10").map(|v| v / 50.0)),
        ("NO2", f(cur, "nitrogen_dioxide").map(|v| v / 40.0)),
        ("O3", f(cur, "ozone").map(|v| v / 120.0)),
        ("SO2", f(cur, "sulphur_dioxide").map(|v| v / 125.0)),
    ];
    candidatos
        .iter()
        .filter_map(|(n, r)| r.map(|r| (n, r)))
        .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal))
        .map(|(n, _)| n.to_string())
        .unwrap_or_else(|| "-".to_string())
}

async fn buscar_ar(http: &reqwest::Client, lat: f64, lon: f64) -> Result<QualidadeAr, ApiError> {
    let url = format!(
        "https://air-quality-api.open-meteo.com/v1/air-quality?latitude={lat}&longitude={lon}\
         &current=european_aqi,us_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone\
         &hourly=pm2_5,pm10,european_aqi&past_days=1&forecast_days=1&timezone=America%2FSao_Paulo"
    );
    let v: Value = http.get(&url).send().await?.error_for_status()?.json().await?;
    let cur = v.get("current").cloned().unwrap_or(Value::Null);
    let aqi = f(&cur, "european_aqi");
    let (classificacao, cor, recomendacao) = classificar_aqi(aqi);

    let horas = arr(&v, "/hourly/time");
    let pm25 = arr(&v, "/hourly/pm2_5");
    let pm10 = arr(&v, "/hourly/pm10");
    let aqis = arr(&v, "/hourly/european_aqi");
    let horario = horas
        .iter()
        .enumerate()
        .map(|(i, h)| PontoHora {
            hora: h.as_str().unwrap_or("").to_string(),
            pm2_5: pm25.get(i).and_then(|x| x.as_f64()),
            pm10: pm10.get(i).and_then(|x| x.as_f64()),
            aqi_eu: aqis.get(i).and_then(|x| x.as_f64()),
        })
        .collect();

    Ok(QualidadeAr {
        latitude: lat,
        longitude: lon,
        aqi_eu: aqi,
        aqi_us: f(&cur, "us_aqi"),
        pm2_5: f(&cur, "pm2_5"),
        pm10: f(&cur, "pm10"),
        co: f(&cur, "carbon_monoxide"),
        no2: f(&cur, "nitrogen_dioxide"),
        so2: f(&cur, "sulphur_dioxide"),
        o3: f(&cur, "ozone"),
        classificacao: classificacao.to_string(),
        cor: cor.to_string(),
        recomendacao: recomendacao.to_string(),
        poluente_dominante: poluente_dominante(&cur),
        horario,
        atualizado_em: agora(),
        fonte: "Open-Meteo Air Quality (CAMS)".to_string(),
    })
}

pub async fn qualidade_ar(ex: &Externo, lat: f64, lon: f64) -> Result<QualidadeAr, ApiError> {
    let chave = format!("{lat:.2},{lon:.2}");
    if let Some(v) = ex.cache_ar.fresco(&chave, TTL_AR) {
        ex.acertos_cache.fetch_add(1, Ordering::Relaxed);
        return Ok(v);
    }
    ex.consultas_externas.fetch_add(1, Ordering::Relaxed);
    match buscar_ar(&ex.http, lat, lon).await {
        Ok(v) => {
            ex.cache_ar.guardar(&chave, v.clone());
            Ok(v)
        }
        Err(e) => {
            tracing::warn!(erro = ?e, "Open-Meteo (ar) indisponível, tentando cache");
            match ex.cache_ar.qualquer(&chave) {
                Some(mut v) => {
                    v.fonte = "cache local (serviço externo indisponível)".to_string();
                    Ok(v)
                }
                None => Err(e),
            }
        }
    }
}

fn descricao_tempo(codigo: i64) -> &'static str {
    match codigo {
        0 => "Céu limpo",
        1 => "Predomínio de sol",
        2 => "Parcialmente nublado",
        3 => "Nublado",
        45 | 48 => "Nevoeiro",
        51 | 53 | 55 => "Garoa",
        56 | 57 => "Garoa congelante",
        61 => "Chuva fraca",
        63 => "Chuva moderada",
        65 => "Chuva forte",
        66 | 67 => "Chuva congelante",
        71 | 73 | 75 | 77 => "Neve",
        80 => "Pancadas de chuva fracas",
        81 => "Pancadas de chuva moderadas",
        82 => "Pancadas de chuva fortes",
        85 | 86 => "Pancadas de neve",
        95 => "Trovoadas",
        96 | 99 => "Trovoadas com granizo",
        _ => "Condição desconhecida",
    }
}

fn risco_alagamento(chuva_24h: f64, prob_max: f64, precip_atual: f64) -> Risco {
    let (nivel, explicacao) = if chuva_24h >= 30.0 || (chuva_24h >= 15.0 && prob_max >= 70.0) || precip_atual >= 10.0 {
        ("alto", format!("Previsão de {chuva_24h:.0} mm de chuva nas próximas 24 h (probabilidade máxima {prob_max:.0}%). Evite áreas baixas, córregos e passagens subterrâneas."))
    } else if chuva_24h >= 8.0 || prob_max >= 60.0 {
        ("moderado", format!("Previsão de {chuva_24h:.0} mm em 24 h com probabilidade de {prob_max:.0}%. Fique atento a pontos conhecidos de alagamento."))
    } else {
        ("baixo", format!("Pouca chuva prevista ({chuva_24h:.0} mm em 24 h, probabilidade {prob_max:.0}%)."))
    };
    Risco { nivel: nivel.to_string(), explicacao }
}

fn risco_inversao(vento: f64, nuvens: f64, hora: u32, mes: u32, umidade: f64) -> Risco {
    let noite_ou_manha = hora <= 9 || hora >= 20;
    let estacao_fria = (5..=8).contains(&mes);
    let (nivel, explicacao) = if vento <= 6.0 && nuvens <= 40.0 && noite_ou_manha && estacao_fria {
        ("alto", format!("Vento fraco ({vento:.0} km/h), céu pouco nublado ({nuvens:.0}%) e período frio favorecem a inversão térmica: a poluição fica presa perto do solo."))
    } else if vento <= 10.0 && nuvens <= 60.0 && (4..=9).contains(&mes) {
        ("moderado", format!("Vento de {vento:.0} km/h e {nuvens:.0}% de nuvens: dispersão de poluentes reduzida."))
    } else if nuvens > 60.0 {
        ("baixo", format!("Céu encoberto ({nuvens:.0}% de nuvens) e umidade de {umidade:.0}% dificultam a formação da inversão térmica."))
    } else if vento > 10.0 {
        ("baixo", format!("Vento de {vento:.0} km/h dispersa os poluentes e impede a inversão térmica."))
    } else {
        ("baixo", format!("Horário e época do ano pouco favoráveis à inversão térmica (vento {vento:.0} km/h, nuvens {nuvens:.0}%)."))
    };
    Risco { nivel: nivel.to_string(), explicacao }
}

async fn buscar_clima(http: &reqwest::Client, lat: f64, lon: f64) -> Result<Clima, ApiError> {
    let url = format!(
        "https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}\
         &current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,cloud_cover,wind_speed_10m,is_day\
         &hourly=temperature_2m,precipitation,precipitation_probability\
         &daily=precipitation_sum,precipitation_probability_max,temperature_2m_max,temperature_2m_min\
         &timezone=America%2FSao_Paulo&forecast_days=2"
    );
    let v: Value = http.get(&url).send().await?.error_for_status()?.json().await?;
    let cur = v.get("current").cloned().unwrap_or(Value::Null);
    let hora_atual = cur.get("time").and_then(|x| x.as_str()).unwrap_or("").to_string();

    let horas = arr(&v, "/hourly/time");
    let temps = arr(&v, "/hourly/temperature_2m");
    let precs = arr(&v, "/hourly/precipitation");
    let probs = arr(&v, "/hourly/precipitation_probability");
    let inicio = horas
        .iter()
        .position(|h| h.as_str().map(|s| s >= hora_atual.as_str()).unwrap_or(false))
        .unwrap_or(0);
    let mut horario = Vec::new();
    let mut chuva_24h = 0.0;
    let mut prob_max: f64 = 0.0;
    for i in inicio..(inicio + 24).min(horas.len()) {
        let precipitacao = precs.get(i).and_then(|x| x.as_f64());
        let probabilidade = probs.get(i).and_then(|x| x.as_f64());
        chuva_24h += precipitacao.unwrap_or(0.0);
        prob_max = prob_max.max(probabilidade.unwrap_or(0.0));
        horario.push(ClimaHora {
            hora: horas[i].as_str().unwrap_or("").to_string(),
            temperatura: temps.get(i).and_then(|x| x.as_f64()),
            precipitacao,
            probabilidade,
        });
    }

    let (hora, mes) = {
        let h = hora_atual.get(11..13).and_then(|s| s.parse::<u32>().ok()).unwrap_or(12);
        let m = hora_atual.get(5..7).and_then(|s| s.parse::<u32>().ok()).unwrap_or(1);
        (h, m)
    };
    let vento = f(&cur, "wind_speed_10m").unwrap_or(10.0);
    let nuvens = f(&cur, "cloud_cover").unwrap_or(50.0);
    let umidade = f(&cur, "relative_humidity_2m").unwrap_or(60.0);
    let precip_atual = f(&cur, "precipitation").unwrap_or(0.0);
    let codigo = cur.get("weather_code").and_then(|x| x.as_i64()).unwrap_or(-1);

    Ok(Clima {
        latitude: lat,
        longitude: lon,
        temperatura: f(&cur, "temperature_2m"),
        sensacao: f(&cur, "apparent_temperature"),
        umidade: Some(umidade),
        precipitacao: Some(precip_atual),
        vento_kmh: Some(vento),
        nebulosidade: Some(nuvens),
        codigo_tempo: codigo,
        descricao_tempo: descricao_tempo(codigo).to_string(),
        eh_dia: cur.get("is_day").and_then(|x| x.as_i64()).unwrap_or(1) == 1,
        chuva_24h_mm: chuva_24h,
        prob_chuva_max: prob_max,
        temp_max: v.pointer("/daily/temperature_2m_max/0").and_then(|x| x.as_f64()),
        temp_min: v.pointer("/daily/temperature_2m_min/0").and_then(|x| x.as_f64()),
        risco_alagamento: risco_alagamento(chuva_24h, prob_max, precip_atual),
        risco_inversao_termica: risco_inversao(vento, nuvens, hora, mes, umidade),
        horario,
        atualizado_em: agora(),
        fonte: "Open-Meteo Forecast".to_string(),
    })
}

pub async fn clima(ex: &Externo, lat: f64, lon: f64) -> Result<Clima, ApiError> {
    let chave = format!("{lat:.2},{lon:.2}");
    if let Some(v) = ex.cache_clima.fresco(&chave, TTL_CLIMA) {
        ex.acertos_cache.fetch_add(1, Ordering::Relaxed);
        return Ok(v);
    }
    ex.consultas_externas.fetch_add(1, Ordering::Relaxed);
    match buscar_clima(&ex.http, lat, lon).await {
        Ok(v) => {
            ex.cache_clima.guardar(&chave, v.clone());
            Ok(v)
        }
        Err(e) => {
            tracing::warn!(erro = ?e, "Open-Meteo (clima) indisponível, tentando cache");
            match ex.cache_clima.qualquer(&chave) {
                Some(mut v) => {
                    v.fonte = "cache local (serviço externo indisponível)".to_string();
                    Ok(v)
                }
                None => Err(e),
            }
        }
    }
}

fn texto(v: &Value, chaves: &[&str]) -> Option<String> {
    chaves.iter().find_map(|k| v.get(k).and_then(|x| x.as_str()).map(|s| s.to_string()))
}

async fn buscar_endereco(http: &reqwest::Client, lat: f64, lon: f64) -> Result<Endereco, ApiError> {
    let url = format!(
        "https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=jsonv2&accept-language=pt-BR&zoom=17"
    );
    let v: Value = http.get(&url).send().await?.error_for_status()?.json().await?;
    let addr = v.get("address").cloned().unwrap_or(Value::Null);
    let rua = texto(&addr, &["road", "pedestrian", "footway", "residential", "path"]);
    let numero = texto(&addr, &["house_number"]);
    let bairro = texto(&addr, &["suburb", "neighbourhood", "quarter", "city_district", "hamlet"]);
    let cidade = texto(&addr, &["city", "town", "village", "municipality", "county"]);
    let estado = texto(&addr, &["state"]);

    let mut partes: Vec<String> = Vec::new();
    if let Some(r) = &rua {
        partes.push(match &numero {
            Some(n) => format!("{r}, {n}"),
            None => r.clone(),
        });
    }
    if let Some(b) = &bairro {
        partes.push(b.clone());
    }
    if let Some(c) = &cidade {
        partes.push(c.clone());
    }
    let endereco = if partes.is_empty() {
        v.get("display_name").and_then(|x| x.as_str()).unwrap_or("Endereço não identificado").to_string()
    } else {
        partes.join(" - ")
    };
    Ok(Endereco { endereco, rua, bairro, cidade, estado, fonte: "Nominatim / OpenStreetMap".to_string() })
}

pub async fn geocode_reverso(ex: &Externo, lat: f64, lon: f64) -> Result<Endereco, ApiError> {
    let chave = format!("{lat:.3},{lon:.3}");
    if let Some(v) = ex.cache_geo.fresco(&chave, TTL_GEO) {
        ex.acertos_cache.fetch_add(1, Ordering::Relaxed);
        return Ok(v);
    }
    ex.consultas_externas.fetch_add(1, Ordering::Relaxed);
    let v = buscar_endereco(&ex.http, lat, lon).await?;
    ex.cache_geo.guardar(&chave, v.clone());
    Ok(v)
}
