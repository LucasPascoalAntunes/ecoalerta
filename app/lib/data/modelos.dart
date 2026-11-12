import 'package:flutter/material.dart';

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
double _d0(dynamic v) => _d(v) ?? 0;
int _i(dynamic v, [int padrao = 0]) => v == null ? padrao : (v as num).toInt();
String _s(dynamic v, [String padrao = '']) => v?.toString() ?? padrao;
String? _sn(dynamic v) => v?.toString();
Map<String, dynamic> _m(dynamic v) => v == null ? {} : Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> _l(dynamic v) =>
    v == null ? [] : (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

typedef FiltroRelatos = ({
  String? categoria,
  String? status,
  String? busca,
  double? lat,
  double? lon,
  double? raioKm,
  String? ordenar,
  bool meus,
});

const FiltroRelatos kFiltroVazio = (
  categoria: null,
  status: null,
  busca: null,
  lat: null,
  lon: null,
  raioKm: null,
  ordenar: null,
  meus: false,
);

class Usuario {
  const Usuario({required this.id, required this.nome, required this.email, required this.papel, required this.criadoEm});
  final int id;
  final String nome;
  final String email;
  final String papel;
  final String criadoEm;
  bool get gestor => papel == 'gestor';

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: _i(j['id']),
        nome: _s(j['nome']),
        email: _s(j['email']),
        papel: _s(j['papel'], 'cidadao'),
        criadoEm: _s(j['criado_em']),
      );
  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'email': email, 'papel': papel, 'criado_em': criadoEm};
}

class Relato {
  const Relato({
    required this.id,
    required this.usuarioId,
    required this.autorNome,
    required this.categoria,
    required this.titulo,
    required this.descricao,
    required this.gravidade,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.endereco,
    this.bairro,
    this.cidade,
    this.fotoUrl,
    required this.confirmacoes,
    required this.comentariosQtd,
    required this.criadoEm,
    required this.atualizadoEm,
    this.resolvidoEm,
    this.distanciaKm,
    this.confirmadoPorMim = false,
  });
  final int id;
  final int usuarioId;
  final String autorNome;
  final String categoria;
  final String titulo;
  final String descricao;
  final int gravidade;
  final String status;
  final double latitude;
  final double longitude;
  final String? endereco;
  final String? bairro;
  final String? cidade;
  final String? fotoUrl;
  final int confirmacoes;
  final int comentariosQtd;
  final String criadoEm;
  final String atualizadoEm;
  final String? resolvidoEm;
  final double? distanciaKm;
  final bool confirmadoPorMim;

  factory Relato.fromJson(Map<String, dynamic> j) => Relato(
        id: _i(j['id']),
        usuarioId: _i(j['usuario_id']),
        autorNome: _s(j['autor_nome']),
        categoria: _s(j['categoria'], 'outro'),
        titulo: _s(j['titulo']),
        descricao: _s(j['descricao']),
        gravidade: _i(j['gravidade'], 3),
        status: _s(j['status'], 'aberto'),
        latitude: _d0(j['latitude']),
        longitude: _d0(j['longitude']),
        endereco: _sn(j['endereco']),
        bairro: _sn(j['bairro']),
        cidade: _sn(j['cidade']),
        fotoUrl: _sn(j['foto_url']),
        confirmacoes: _i(j['confirmacoes']),
        comentariosQtd: _i(j['comentarios_qtd']),
        criadoEm: _s(j['criado_em']),
        atualizadoEm: _s(j['atualizado_em']),
        resolvidoEm: _sn(j['resolvido_em']),
        distanciaKm: _d(j['distancia_km']),
        confirmadoPorMim: j['confirmado_por_mim'] == true,
      );

  String get local => [bairro, cidade].where((e) => e != null && e.isNotEmpty).join(', ');
}

class Comentario {
  const Comentario({required this.id, required this.relatoId, required this.usuarioId, required this.autorNome, required this.texto, required this.criadoEm});
  final int id;
  final int relatoId;
  final int usuarioId;
  final String autorNome;
  final String texto;
  final String criadoEm;
  factory Comentario.fromJson(Map<String, dynamic> j) => Comentario(
        id: _i(j['id']),
        relatoId: _i(j['relato_id']),
        usuarioId: _i(j['usuario_id']),
        autorNome: _s(j['autor_nome']),
        texto: _s(j['texto']),
        criadoEm: _s(j['criado_em']),
      );
}

class HistoricoStatus {
  const HistoricoStatus({required this.id, required this.autorNome, required this.deStatus, required this.paraStatus, this.observacao, required this.criadoEm});
  final int id;
  final String autorNome;
  final String deStatus;
  final String paraStatus;
  final String? observacao;
  final String criadoEm;
  factory HistoricoStatus.fromJson(Map<String, dynamic> j) => HistoricoStatus(
        id: _i(j['id']),
        autorNome: _s(j['autor_nome']),
        deStatus: _s(j['de_status']),
        paraStatus: _s(j['para_status']),
        observacao: _sn(j['observacao']),
        criadoEm: _s(j['criado_em']),
      );
}

class PontoHora {
  const PontoHora({required this.hora, this.pm25, this.pm10, this.aqiEu});
  final String hora;
  final double? pm25;
  final double? pm10;
  final double? aqiEu;
  factory PontoHora.fromJson(Map<String, dynamic> j) =>
      PontoHora(hora: _s(j['hora']), pm25: _d(j['pm2_5']), pm10: _d(j['pm10']), aqiEu: _d(j['aqi_eu']));
}

Color corHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h, radix: 16) | 0xFF000000);
}

class QualidadeAr {
  const QualidadeAr({
    required this.latitude,
    required this.longitude,
    this.aqiEu,
    this.aqiUs,
    this.pm25,
    this.pm10,
    this.co,
    this.no2,
    this.so2,
    this.o3,
    required this.classificacao,
    required this.cor,
    required this.recomendacao,
    required this.poluenteDominante,
    required this.horario,
    required this.atualizadoEm,
    required this.fonte,
  });
  final double latitude, longitude;
  final double? aqiEu, aqiUs, pm25, pm10, co, no2, so2, o3;
  final String classificacao, cor, recomendacao, poluenteDominante, atualizadoEm, fonte;
  final List<PontoHora> horario;
  Color get corValor => corHex(cor);

  factory QualidadeAr.fromJson(Map<String, dynamic> j) => QualidadeAr(
        latitude: _d0(j['latitude']),
        longitude: _d0(j['longitude']),
        aqiEu: _d(j['aqi_eu']),
        aqiUs: _d(j['aqi_us']),
        pm25: _d(j['pm2_5']),
        pm10: _d(j['pm10']),
        co: _d(j['co']),
        no2: _d(j['no2']),
        so2: _d(j['so2']),
        o3: _d(j['o3']),
        classificacao: _s(j['classificacao'], 'Indisponível'),
        cor: _s(j['cor'], '#9E9E9E'),
        recomendacao: _s(j['recomendacao']),
        poluenteDominante: _s(j['poluente_dominante'], '-'),
        horario: _l(j['horario']).map(PontoHora.fromJson).toList(),
        atualizadoEm: _s(j['atualizado_em']),
        fonte: _s(j['fonte']),
      );
}

class Risco {
  const Risco({required this.nivel, required this.explicacao});
  final String nivel;
  final String explicacao;
  String get rotulo => switch (nivel) { 'alto' => 'Alto', 'moderado' => 'Moderado', _ => 'Baixo' };
  factory Risco.fromJson(Map<String, dynamic> j) => Risco(nivel: _s(j['nivel'], 'baixo'), explicacao: _s(j['explicacao']));
}

class ClimaHora {
  const ClimaHora({required this.hora, this.temperatura, this.precipitacao, this.probabilidade});
  final String hora;
  final double? temperatura, precipitacao, probabilidade;
  factory ClimaHora.fromJson(Map<String, dynamic> j) => ClimaHora(
      hora: _s(j['hora']), temperatura: _d(j['temperatura']), precipitacao: _d(j['precipitacao']), probabilidade: _d(j['probabilidade']));
}

class Clima {
  const Clima({
    this.temperatura,
    this.sensacao,
    this.umidade,
    this.precipitacao,
    this.ventoKmh,
    this.nebulosidade,
    required this.codigoTempo,
    required this.descricaoTempo,
    required this.ehDia,
    required this.chuva24hMm,
    required this.probChuvaMax,
    this.tempMax,
    this.tempMin,
    required this.riscoAlagamento,
    required this.riscoInversaoTermica,
    required this.horario,
    required this.atualizadoEm,
    required this.fonte,
  });
  final double? temperatura, sensacao, umidade, precipitacao, ventoKmh, nebulosidade, tempMax, tempMin;
  final int codigoTempo;
  final String descricaoTempo, atualizadoEm, fonte;
  final bool ehDia;
  final double chuva24hMm, probChuvaMax;
  final Risco riscoAlagamento, riscoInversaoTermica;
  final List<ClimaHora> horario;

  IconData get icone {
    if (codigoTempo == 0) return ehDia ? Icons.wb_sunny : Icons.nightlight_round;
    if (codigoTempo <= 3) return Icons.wb_cloudy;
    if (codigoTempo <= 48) return Icons.foggy;
    if (codigoTempo <= 67) return Icons.umbrella;
    if (codigoTempo <= 77) return Icons.ac_unit;
    if (codigoTempo <= 82) return Icons.grain;
    return Icons.thunderstorm;
  }

  factory Clima.fromJson(Map<String, dynamic> j) => Clima(
        temperatura: _d(j['temperatura']),
        sensacao: _d(j['sensacao']),
        umidade: _d(j['umidade']),
        precipitacao: _d(j['precipitacao']),
        ventoKmh: _d(j['vento_kmh']),
        nebulosidade: _d(j['nebulosidade']),
        codigoTempo: _i(j['codigo_tempo'], -1),
        descricaoTempo: _s(j['descricao_tempo']),
        ehDia: j['eh_dia'] != false,
        chuva24hMm: _d0(j['chuva_24h_mm']),
        probChuvaMax: _d0(j['prob_chuva_max']),
        tempMax: _d(j['temp_max']),
        tempMin: _d(j['temp_min']),
        riscoAlagamento: Risco.fromJson(_m(j['risco_alagamento'])),
        riscoInversaoTermica: Risco.fromJson(_m(j['risco_inversao_termica'])),
        horario: _l(j['horario']).map(ClimaHora.fromJson).toList(),
        atualizadoEm: _s(j['atualizado_em']),
        fonte: _s(j['fonte']),
      );
}

class Endereco {
  const Endereco({required this.endereco, this.rua, this.bairro, this.cidade, this.estado});
  final String endereco;
  final String? rua, bairro, cidade, estado;
  factory Endereco.fromJson(Map<String, dynamic> j) => Endereco(
      endereco: _s(j['endereco']), rua: _sn(j['rua']), bairro: _sn(j['bairro']), cidade: _sn(j['cidade']), estado: _sn(j['estado']));
}

class PontoMonitorado {
  const PontoMonitorado({required this.id, required this.nome, required this.latitude, required this.longitude, this.aqiEu, this.pm25, this.pm10, this.coletadoEm, this.totalAmostras = 0});
  final int id;
  final String nome;
  final double latitude, longitude;
  final double? aqiEu, pm25, pm10;
  final String? coletadoEm;
  final int totalAmostras;
  factory PontoMonitorado.fromJson(Map<String, dynamic> j) => PontoMonitorado(
        id: _i(j['id']),
        nome: _s(j['nome']),
        latitude: _d0(j['latitude']),
        longitude: _d0(j['longitude']),
        aqiEu: _d(j['aqi_eu']),
        pm25: _d(j['pm2_5']),
        pm10: _d(j['pm10']),
        coletadoEm: _sn(j['coletado_em']),
        totalAmostras: _i(j['total_amostras']),
      );
}

class AmostraAr {
  const AmostraAr({required this.id, this.aqiEu, this.pm25, this.pm10, this.no2, this.o3, required this.coletadoEm});
  final int id;
  final double? aqiEu, pm25, pm10, no2, o3;
  final String coletadoEm;
  factory AmostraAr.fromJson(Map<String, dynamic> j) => AmostraAr(
      id: _i(j['id']), aqiEu: _d(j['aqi_eu']), pm25: _d(j['pm2_5']), pm10: _d(j['pm10']), no2: _d(j['no2']), o3: _d(j['o3']), coletadoEm: _s(j['coletado_em']));
}

class HistoricoAr {
  const HistoricoAr({required this.ponto, this.distanciaKm, required this.amostras});
  final PontoMonitorado ponto;
  final double? distanciaKm;
  final List<AmostraAr> amostras;
  factory HistoricoAr.fromJson(Map<String, dynamic> j) => HistoricoAr(
        ponto: PontoMonitorado.fromJson(_m(j['ponto'])),
        distanciaKm: _d(j['distancia_km']),
        amostras: _l(j['amostras']).map(AmostraAr.fromJson).toList(),
      );
}

class Contagem {
  const Contagem(this.nome, this.total);
  final String nome;
  final int total;
  factory Contagem.fromJson(Map<String, dynamic> j) => Contagem(_s(j['nome']), _i(j['total']));
}

class Estatisticas {
  const Estatisticas({
    required this.totalRelatos,
    required this.abertos,
    required this.emAnalise,
    required this.resolvidos,
    required this.invalidos,
    required this.ultimos7Dias,
    required this.ultimas24h,
    required this.totalUsuarios,
    required this.totalConfirmacoes,
    required this.totalComentarios,
    required this.totalAmostrasAr,
    required this.taxaResolucaoPct,
    this.tempoMedioResolucaoHoras,
    this.gravidadeMedia,
    required this.porCategoria,
    required this.porStatus,
    required this.porGravidade,
    required this.porDia,
    required this.porBairro,
    required this.porCidade,
    required this.maisConfirmados,
    required this.geradoEm,
  });
  final int totalRelatos, abertos, emAnalise, resolvidos, invalidos, ultimos7Dias, ultimas24h, totalUsuarios, totalConfirmacoes, totalComentarios, totalAmostrasAr;
  final double taxaResolucaoPct;
  final double? tempoMedioResolucaoHoras, gravidadeMedia;
  final List<Contagem> porCategoria, porStatus, porGravidade, porDia, porBairro, porCidade;
  final List<Relato> maisConfirmados;
  final String geradoEm;

  factory Estatisticas.fromJson(Map<String, dynamic> j) => Estatisticas(
        totalRelatos: _i(j['total_relatos']),
        abertos: _i(j['abertos']),
        emAnalise: _i(j['em_analise']),
        resolvidos: _i(j['resolvidos']),
        invalidos: _i(j['invalidos']),
        ultimos7Dias: _i(j['ultimos_7_dias']),
        ultimas24h: _i(j['ultimas_24h']),
        totalUsuarios: _i(j['total_usuarios']),
        totalConfirmacoes: _i(j['total_confirmacoes']),
        totalComentarios: _i(j['total_comentarios']),
        totalAmostrasAr: _i(j['total_amostras_ar']),
        taxaResolucaoPct: _d0(j['taxa_resolucao_pct']),
        tempoMedioResolucaoHoras: _d(j['tempo_medio_resolucao_horas']),
        gravidadeMedia: _d(j['gravidade_media']),
        porCategoria: _l(j['por_categoria']).map(Contagem.fromJson).toList(),
        porStatus: _l(j['por_status']).map(Contagem.fromJson).toList(),
        porGravidade: _l(j['por_gravidade']).map(Contagem.fromJson).toList(),
        porDia: _l(j['por_dia']).map(Contagem.fromJson).toList(),
        porBairro: _l(j['por_bairro']).map(Contagem.fromJson).toList(),
        porCidade: _l(j['por_cidade']).map(Contagem.fromJson).toList(),
        maisConfirmados: _l(j['mais_confirmados']).map(Relato.fromJson).toList(),
        geradoEm: _s(j['gerado_em']),
      );
}
