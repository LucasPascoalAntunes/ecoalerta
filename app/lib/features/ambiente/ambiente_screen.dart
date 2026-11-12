import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categorias.dart';
import '../../core/formatadores.dart';
import '../../data/api.dart';
import '../../data/localizacao.dart';
import '../../data/modelos.dart';
import '../../data/provedores.dart';
import '../../data/sessao.dart';
import '../../widgets/comuns.dart';

Color corAqi(double? aqi) {
  if (aqi == null) return Colors.grey;
  if (aqi <= 20) return const Color(0xFF2E7D32);
  if (aqi <= 40) return const Color(0xFF7CB342);
  if (aqi <= 60) return const Color(0xFFF9A825);
  if (aqi <= 80) return const Color(0xFFEF6C00);
  if (aqi <= 100) return const Color(0xFFC62828);
  return const Color(0xFF6A1B9A);
}

String rotuloAqi(double? aqi) {
  if (aqi == null) return 'Sem dados';
  if (aqi <= 20) return 'Boa';
  if (aqi <= 40) return 'Razoável';
  if (aqi <= 60) return 'Moderada';
  if (aqi <= 80) return 'Ruim';
  if (aqi <= 100) return 'Muito ruim';
  return 'Extrema';
}

class AmbienteScreen extends ConsumerWidget {
  const AmbienteScreen({super.key});

  void _atualizar(WidgetRef ref) {
    ref.invalidate(posicaoProvider);
    ref.invalidate(arProvider);
    ref.invalidate(climaProvider);
    ref.invalidate(pontosProvider);
    ref.invalidate(historicoArProvider);
  }

  Future<void> _coletarAgora(BuildContext context, WidgetRef ref) async {
    try {
      final n = await ref.read(apiProvider).coletarAgora();
      ref.invalidate(pontosProvider);
      ref.invalidate(historicoArProvider);
      if (context.mounted) mostrarSnack(context, 'Coleta feita em $n pontos');
    } on ApiException catch (e) {
      if (context.mounted) mostrarSnack(context, e.mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final pos = ref.watch(posicaoProvider).value ?? kPosicaoPadrao;
    final chave = (pos.lat, pos.lon);
    final ar = ref.watch(arProvider(chave));
    final clima = ref.watch(climaProvider(chave));
    final pontos = ref.watch(pontosProvider);
    final historico = ref.watch(historicoArProvider(chave));
    final gestor = ref.watch(sessaoProvider)?.gestor == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ar e clima'),
        actions: [IconButton(tooltip: 'Atualizar', onPressed: () => _atualizar(ref), icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _atualizar(ref),
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Icon(pos.real ? Icons.my_location : Icons.location_city_outlined, size: 15, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pos.real ? 'Sua posição atual' : (pos.aviso ?? 'Posição padrão'),
                  style: t.textTheme.bodySmall,
                ),
              ),
            ]),
          ),
          const Rotulo('Qualidade do ar', topo: 14),
          ar.when(
            loading: () => const Bloco(child: SizedBox(height: 140, child: Carregando())),
            error: (e, _) => Bloco(child: ErroCarregar(e, onTentar: () => ref.invalidate(arProvider(chave)))),
            data: (q) => _BlocoAr(q),
          ),
          const Rotulo('Clima e riscos'),
          clima.when(
            loading: () => const Bloco(child: SizedBox(height: 120, child: Carregando())),
            error: (e, _) => Bloco(child: ErroCarregar(e, onTentar: () => ref.invalidate(climaProvider(chave)))),
            data: (c) => _BlocoClima(c),
          ),
          Rotulo(
            'Pontos monitorados',
            acao: gestor ? TextButton(onPressed: () => _coletarAgora(context, ref), child: const Text('Coletar agora')) : null,
          ),
          pontos.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErroCarregar(e, onTentar: () => ref.invalidate(pontosProvider)),
            data: (ps) => Bloco(
              child: Column(children: [
                for (var i = 0; i < ps.length; i++) ...[
                  if (i > 0) const Divider(indent: 16),
                  ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: corAqi(ps[i].aqiEu), borderRadius: BorderRadius.circular(10)),
                      child: Text(ps[i].aqiEu?.toStringAsFixed(0) ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(ps[i].nome),
                    subtitle: Text(ps[i].coletadoEm == null
                        ? 'Aguardando a primeira coleta'
                        : '${rotuloAqi(ps[i].aqiEu)} · PM2.5 ${numero(ps[i].pm25, 1)} µg/m³ · ${tempoRelativo(ps[i].coletadoEm)}'),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('O servidor consulta esses pontos a cada 30 minutos e guarda o histórico.', style: t.textTheme.bodySmall),
          ),
          const Rotulo('Histórico do ponto mais próximo'),
          historico.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErroCarregar(e, onTentar: () => ref.invalidate(historicoArProvider(chave))),
            data: (h) => _BlocoHistorico(h),
          ),
        ]),
      ),
    );
  }
}

FlTitlesData _titulos(List<String> rotulosX, {double intervalo = 6}) => FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: intervalo,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= rotulosX.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(rotulosX[i], style: const TextStyle(fontSize: 10)));
          },
        ),
      ),
    );

class _BlocoAr extends StatelessWidget {
  const _BlocoAr(this.q);
  final QualidadeAr q;

  List<PontoHora> get _ultimas24 {
    final agora = DateTime.now();
    final chave = '${agora.year.toString().padLeft(4, '0')}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}T${agora.hour.toString().padLeft(2, '0')}:00';
    var idx = q.horario.indexWhere((h) => h.hora.compareTo(chave) >= 0);
    if (idx < 0) idx = q.horario.length - 1;
    final ini = (idx - 23).clamp(0, q.horario.length);
    return q.horario.sublist(ini, (idx + 1).clamp(0, q.horario.length));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cor = q.corValor;
    final serie = _ultimas24;
    final medidas = <(String, double?)>[('PM2.5', q.pm25), ('PM10', q.pm10), ('NO₂', q.no2), ('O₃', q.o3), ('SO₂', q.so2), ('CO', q.co)];
    return Bloco(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(14)),
            child: Text(q.aqiEu?.toStringAsFixed(0) ?? '-', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.classificacao, style: t.textTheme.titleLarge?.copyWith(color: cor)),
              const SizedBox(height: 2),
              Text('Índice europeu de qualidade do ar', style: t.textTheme.bodySmall),
              Text('Poluente predominante: ${q.poluenteDominante}', style: t.textTheme.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(q.recomendacao, style: t.textTheme.bodyMedium),
        const SizedBox(height: 14),
        Divider(color: t.colorScheme.outlineVariant),
        for (var i = 0; i < medidas.length; i += 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              for (var j = i; j < i + 2 && j < medidas.length; j++)
                Expanded(
                  child: Row(children: [
                    Text(medidas[j].$1, style: t.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Text(medidas[j].$2 == null ? '-' : '${numero(medidas[j].$2, 1)} µg/m³', style: t.textTheme.labelLarge),
                  ]),
                ),
            ]),
          ),
        Divider(color: t.colorScheme.outlineVariant),
        const SizedBox(height: 8),
        Text('PM2.5 nas últimas 24 horas (µg/m³)', style: t.textTheme.labelLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: serie.length < 2
              ? Center(child: Text('Sem série horária', style: t.textTheme.bodySmall))
              : LineChart(LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: _titulos([for (final h in serie) h.hora.length >= 16 ? h.hora.substring(11, 16) : '']),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < serie.length; i++) FlSpot(i.toDouble(), serie[i].pm25 ?? 0)],
                      isCurved: true,
                      color: cor,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: cor.withValues(alpha: .12)),
                    ),
                  ],
                )),
        ),
        const SizedBox(height: 8),
        Text('Fonte: ${q.fonte}. Atualizado às ${horaCurta(q.atualizadoEm)}.', style: t.textTheme.labelSmall),
      ]),
    );
  }
}

class _BlocoClima extends StatelessWidget {
  const _BlocoClima(this.c);
  final Clima c;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Bloco(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Icon(c.icone, size: 40, color: t.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${c.temperatura?.toStringAsFixed(0) ?? '-'}°', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(width: 8),
                  Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(c.descricaoTempo, style: t.textTheme.labelLarge)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Sensação ${c.sensacao?.toStringAsFixed(0) ?? '-'}°  ·  Umidade ${c.umidade?.toStringAsFixed(0) ?? '-'}%  ·  Vento ${c.ventoKmh?.toStringAsFixed(0) ?? '-'} km/h',
                  style: t.textTheme.bodySmall,
                ),
                Text(
                  'Mín. ${c.tempMin?.toStringAsFixed(0) ?? '-'}°  ·  Máx. ${c.tempMax?.toStringAsFixed(0) ?? '-'}°  ·  Chuva prevista em 24 h: ${c.chuva24hMm.toStringAsFixed(0)} mm (${c.probChuvaMax.toStringAsFixed(0)}%)',
                  style: t.textTheme.bodySmall,
                ),
              ]),
            ),
          ]),
        ),
        const Divider(indent: 16),
        _LinhaRisco(icone: Icons.water_outlined, titulo: 'Risco de alagamento', risco: c.riscoAlagamento),
        const Divider(indent: 16),
        _LinhaRisco(icone: Icons.foggy, titulo: 'Risco de inversão térmica', risco: c.riscoInversaoTermica),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(alignment: Alignment.centerLeft, child: Text('Fonte: ${c.fonte}. Atualizado às ${horaCurta(c.atualizadoEm)}.', style: t.textTheme.labelSmall)),
        ),
      ]),
    );
  }
}

class _LinhaRisco extends StatelessWidget {
  const _LinhaRisco({required this.icone, required this.titulo, required this.risco});
  final IconData icone;
  final String titulo;
  final Risco risco;
  @override
  Widget build(BuildContext context) {
    final cor = corRisco(risco.nivel);
    return ListTile(
      leading: Icon(icone, color: cor),
      title: Row(children: [
        Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(risco.rotulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
      subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(risco.explicacao)),
    );
  }
}

class _BlocoHistorico extends StatelessWidget {
  const _BlocoHistorico(this.h);
  final HistoricoAr h;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = h.amostras;
    return Bloco(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(h.ponto.nome, style: t.textTheme.labelLarge),
        Text('${h.distanciaKm == null ? '' : 'A ${distancia(h.distanciaKm)} daqui. '}${a.length} amostras nos últimos 7 dias.', style: t.textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: a.length < 2
              ? Center(child: Text('Ainda não há amostras suficientes.', style: t.textTheme.bodySmall))
              : LineChart(LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  titlesData: _titulos([for (final x in a) '${diaMes(x.coletadoEm)} ${horaCurta(x.coletadoEm)}'], intervalo: (a.length / 4).ceilToDouble().clamp(1, 1000)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < a.length; i++) FlSpot(i.toDouble(), a[i].aqiEu ?? 0)],
                      isCurved: false,
                      color: t.colorScheme.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                )),
        ),
        const SizedBox(height: 6),
        Text('Índice de qualidade do ar por coleta', style: t.textTheme.labelSmall),
      ]),
    );
  }
}
