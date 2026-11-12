import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/categorias.dart';
import '../../core/formatadores.dart';
import '../../data/api.dart';
import '../../data/modelos.dart';
import '../../data/provedores.dart';
import '../../widgets/comuns.dart';
import '../relato/detalhe_relato_screen.dart';

class PainelScreen extends ConsumerStatefulWidget {
  const PainelScreen({super.key});
  @override
  ConsumerState<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends ConsumerState<PainelScreen> {
  bool _exportando = false;

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      final csv = await ref.read(apiProvider).exportarCsv();
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: 'ecoalerta-ocorrencias.csv')],
        subject: 'Ocorrências EcoAlerta (CSV)',
      ));
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.mensagem, erro: true);
    } catch (_) {
      if (mounted) mostrarSnack(context, 'Não foi possível compartilhar o arquivo', erro: true);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final est = ref.watch(estatisticasProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: _exportando ? null : _exportar,
            icon: _exportando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined),
          ),
          IconButton(tooltip: 'Atualizar', onPressed: () => ref.invalidate(estatisticasProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: est.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroCarregar(e, onTentar: () => ref.invalidate(estatisticasProvider)),
        data: (e) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(estatisticasProvider),
          child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  Indicador(titulo: 'Ocorrências registradas', valor: '${e.totalRelatos}'),
                  Indicador(titulo: 'Em aberto', valor: '${e.abertos}', cor: statusPorId('aberto').cor),
                  Indicador(titulo: 'Em análise', valor: '${e.emAnalise}', cor: statusPorId('em_analise').cor),
                  Indicador(titulo: 'Resolvidas', valor: '${e.resolvidos}', cor: statusPorId('resolvido').cor),
                  Indicador(titulo: 'Taxa de resolução', valor: '${e.taxaResolucaoPct.toStringAsFixed(0)}%'),
                  Indicador(titulo: 'Tempo médio até resolver', valor: horas(e.tempoMedioResolucaoHoras)),
                  Indicador(titulo: 'Últimos 7 dias', valor: '${e.ultimos7Dias}'),
                  Indicador(titulo: 'Confirmações da comunidade', valor: '${e.totalConfirmacoes}'),
                ],
              ),
            ),
            const Rotulo('Por categoria'),
            Bloco(padding: const EdgeInsets.all(16), child: _Pizza(e.porCategoria)),
            const Rotulo('Por dia, últimos 30 dias'),
            Bloco(padding: const EdgeInsets.fromLTRB(8, 16, 16, 8), child: SizedBox(height: 170, child: _BarrasDia(e.porDia))),
            const Rotulo('Bairros com mais ocorrências'),
            Bloco(padding: const EdgeInsets.all(16), child: _BarrasHorizontais(e.porBairro, t.colorScheme.primary)),
            const Rotulo('Por gravidade'),
            Bloco(
              padding: const EdgeInsets.all(16),
              child: _BarrasHorizontais(
                [for (final c in e.porGravidade) Contagem('${c.nome}. ${kGravidades[int.tryParse(c.nome) ?? 3] ?? ''}', c.total)],
                t.colorScheme.tertiary,
              ),
            ),
            const Rotulo('Mais confirmadas'),
            Bloco(
              child: Column(children: [
                for (var i = 0; i < e.maisConfirmados.length; i++) ...[
                  if (i > 0) const Divider(indent: 16),
                  ItemOcorrencia(
                    e.maisConfirmados[i],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheRelatoScreen(id: e.maisConfirmados[i].id))),
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: OutlinedButton.icon(onPressed: _exportando ? null : _exportar, icon: const Icon(Icons.table_chart_outlined), label: const Text('Exportar planilha (CSV)')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text('Dados calculados pelo servidor às ${horaCurta(e.geradoEm)}.', style: t.textTheme.labelSmall),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pizza extends StatelessWidget {
  const _Pizza(this.itens);
  final List<Contagem> itens;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = itens.fold<int>(0, (s, c) => s + c.total);
    final comDados = itens.where((c) => c.total > 0).toList()..sort((a, b) => b.total.compareTo(a.total));
    if (total == 0) return const SizedBox(height: 100, child: EstadoVazio(icone: Icons.pie_chart_outline, titulo: 'Sem dados'));
    return Row(children: [
      SizedBox(
        width: 150,
        height: 150,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            for (final c in comDados)
              PieChartSectionData(
                value: c.total.toDouble(),
                color: categoriaPorId(c.nome).cor,
                radius: 38,
                title: c.total * 100 / total >= 8 ? '${(c.total * 100 / total).round()}%' : '',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
          ],
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final c in comDados)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: categoriaPorId(c.nome).cor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(child: Text(categoriaPorId(c.nome).nome, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
                Text('${c.total}', style: t.textTheme.labelMedium),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _BarrasDia extends StatelessWidget {
  const _BarrasDia(this.itens);
  final List<Contagem> itens;
  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final maxY = itens.fold<int>(0, (m, c) => c.total > m ? c.total : m).toDouble();
    return BarChart(BarChartData(
      maxY: maxY < 3 ? 3 : maxY + 1,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${diaMes('${itens[g.x].nome}T00:00:00')}: ${rod.toY.toInt()}', const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i < 0 || i >= itens.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4), child: Text(itens[i].nome.substring(5).replaceAll('-', '/'), style: const TextStyle(fontSize: 10)));
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < itens.length; i++)
          BarChartGroupData(x: i, barRods: [BarChartRodData(toY: itens[i].total.toDouble(), color: cor, width: 6, borderRadius: BorderRadius.circular(2))]),
      ],
    ));
  }
}

class _BarrasHorizontais extends StatelessWidget {
  const _BarrasHorizontais(this.itens, this.cor);
  final List<Contagem> itens;
  final Color cor;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (itens.isEmpty) return Text('Sem dados', style: t.textTheme.bodySmall);
    final max = itens.fold<int>(1, (m, c) => c.total > m ? c.total : m);
    return Column(children: [
      for (final c in itens)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 118, child: Text(c.nome, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: c.total / max, minHeight: 10, color: cor, backgroundColor: t.colorScheme.surfaceContainerHigh),
              ),
            ),
            SizedBox(width: 30, child: Text('${c.total}', textAlign: TextAlign.right, style: t.textTheme.labelMedium)),
          ]),
        ),
    ]);
  }
}
