import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/categorias.dart';
import '../../core/formatadores.dart';
import '../../data/api.dart';
import '../../data/config.dart';
import '../../data/modelos.dart';
import '../../data/provedores.dart';
import '../../data/sessao.dart';
import '../../widgets/comuns.dart';

class DetalheRelatoScreen extends ConsumerStatefulWidget {
  const DetalheRelatoScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<DetalheRelatoScreen> createState() => _DetalheRelatoScreenState();
}

class _DetalheRelatoScreenState extends ConsumerState<DetalheRelatoScreen> {
  final _comentario = TextEditingController();
  bool _confirmando = false;
  bool _comentando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  void _recarregar() {
    ref.invalidate(relatoProvider(widget.id));
    ref.invalidate(comentariosProvider(widget.id));
    ref.invalidate(historicoProvider(widget.id));
    ref.invalidate(relatosProvider);
    ref.invalidate(estatisticasProvider);
  }

  Future<void> _confirmar() async {
    setState(() => _confirmando = true);
    try {
      final r = await ref.read(apiProvider).confirmar(widget.id);
      _recarregar();
      if (mounted) mostrarSnack(context, r.confirmadoPorMim ? 'Confirmação registrada' : 'Confirmação removida');
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  Future<void> _comentar() async {
    final texto = _comentario.text.trim();
    if (texto.isEmpty) return;
    setState(() => _comentando = true);
    try {
      await ref.read(apiProvider).comentar(widget.id, texto);
      _comentario.clear();
      if (mounted) FocusScope.of(context).unfocus();
      _recarregar();
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _comentando = false);
    }
  }

  Future<void> _alterarStatus(Relato r) async {
    var escolhido = r.status;
    final obs = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(alignment: Alignment.centerLeft, child: Text('Atualizar situação', style: Theme.of(ctx).textTheme.titleMedium)),
              ),
              RadioGroup<String>(
                groupValue: escolhido,
                onChanged: (v) => setSheet(() => escolhido = v ?? escolhido),
                child: Column(children: [
                  for (final s in kStatus)
                    RadioListTile<String>(value: s.id, title: Text(s.rotulo), secondary: Icon(s.icone, color: s.cor), dense: true),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(controller: obs, decoration: const InputDecoration(labelText: 'Observação (opcional)'), maxLines: 2, textCapitalization: TextCapitalization.sentences),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: BotaoPrimario('Salvar', onPressed: () => Navigator.pop(ctx, true)),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || escolhido == r.status) return;
    try {
      await ref.read(apiProvider).alterarStatus(widget.id, escolhido, obs.text);
      _recarregar();
      if (mounted) mostrarSnack(context, 'Situação atualizada para ${statusPorId(escolhido).rotulo.toLowerCase()}');
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.mensagem, erro: true);
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir esta ocorrência?'),
        content: const Text('Os comentários e confirmações também serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).excluir(widget.id);
      ref.invalidate(relatosProvider);
      ref.invalidate(estatisticasProvider);
      if (mounted) {
        mostrarSnack(context, 'Ocorrência excluída');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.mensagem, erro: true);
    }
  }

  void _compartilhar(Relato r) {
    final cat = categoriaPorId(r.categoria);
    SharePlus.instance.share(ShareParams(
      subject: 'EcoAlerta: ${r.titulo}',
      text: '${cat.nome}: ${r.titulo}\n${r.descricao}\nLocal: ${r.endereco ?? r.local}\n'
          'Situação: ${statusPorId(r.status).rotulo}. ${r.confirmacoes} confirmações.\n'
          'https://www.openstreetmap.org/?mlat=${r.latitude}&mlon=${r.longitude}#map=17/${r.latitude}/${r.longitude}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sessao = ref.watch(sessaoProvider);
    final base = ref.watch(configProvider).servidorUrl;
    final relato = ref.watch(relatoProvider(widget.id));
    final r = relato.value;
    final podeExcluir = r != null && sessao != null && (sessao.gestor || r.usuarioId == sessao.usuario.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocorrência'),
        actions: [
          if (r != null) IconButton(tooltip: 'Compartilhar', onPressed: () => _compartilhar(r), icon: const Icon(Icons.share_outlined)),
          if (podeExcluir)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'excluir' ? _excluir() : null,
              itemBuilder: (_) => const [PopupMenuItem(value: 'excluir', child: Text('Excluir ocorrência'))],
            ),
        ],
      ),
      body: relato.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroCarregar(e, onTentar: _recarregar),
        data: (r) {
          final cat = categoriaPorId(r.categoria);
          final meu = sessao?.usuario.id == r.usuarioId;
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              if (r.fotoUrl != null)
                CachedNetworkImage(
                  imageUrl: urlAbsoluta(base, r.fotoUrl),
                  height: 230,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(height: 230, color: t.colorScheme.surfaceContainerHigh),
                  errorWidget: (_, _, _) => Container(height: 120, color: t.colorScheme.surfaceContainerHigh, child: const Center(child: Icon(Icons.broken_image_outlined))),
                ),
              Bloco(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconeCategoria(r.categoria, tamanho: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cat.nome.toUpperCase(), style: TextStyle(color: cat.cor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: .4)),
                        const SizedBox(height: 2),
                        Text(r.titulo, style: t.textTheme.titleLarge),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Situacao(r.status),
                    const SizedBox(width: 14),
                    NivelGravidade(r.gravidade),
                  ]),
                  const SizedBox(height: 6),
                  Text('Registrada por ${r.autorNome}, ${tempoRelativo(r.criadoEm)}', style: t.textTheme.bodySmall),
                  const SizedBox(height: 14),
                  Text(r.descricao, style: t.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (meu || _confirmando || sessao == null) ? null : _confirmar,
                        style: r.confirmadoPorMim
                            ? OutlinedButton.styleFrom(backgroundColor: t.colorScheme.primaryContainer, foregroundColor: t.colorScheme.onPrimaryContainer, side: BorderSide(color: t.colorScheme.primaryContainer))
                            : null,
                        icon: Icon(r.confirmadoPorMim ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
                        label: Text(r.confirmadoPorMim ? 'Confirmada (${r.confirmacoes})' : 'Também vi (${r.confirmacoes})'),
                      ),
                    ),
                    if (sessao?.gestor == true) ...[
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(onPressed: () => _alterarStatus(r), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Atualizar'))),
                    ],
                  ]),
                  if (meu) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Você registrou esta ocorrência.', style: t.textTheme.bodySmall)),
                ]),
              ),
              const Rotulo('Local'),
              Bloco(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.endereco ?? r.local, style: const TextStyle(fontSize: 14)),
                    subtitle: Text([r.local, if (r.distanciaKm != null) 'a ${distancia(r.distanciaKm)} de você'].where((e) => e.isNotEmpty).join(' · ')),
                  ),
                  SizedBox(
                    height: 160,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(r.latitude, r.longitude),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'br.com.ecoalerta.ecoalerta'),
                        MarkerLayer(markers: [
                          Marker(point: LatLng(r.latitude, r.longitude), width: 40, height: 40, alignment: Alignment.topCenter, child: Icon(Icons.location_on, color: cat.cor, size: 40)),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
              const Rotulo('Andamento'),
              Bloco(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: _Andamento(id: widget.id, r: r)),
              Rotulo('Comentários (${r.comentariosQtd})'),
              Bloco(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(children: [
                  _Comentarios(id: widget.id),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _comentario,
                        maxLength: 1000,
                        decoration: const InputDecoration(hintText: 'Escrever comentário', isDense: true, counterText: ''),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _comentar(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _comentando ? null : _comentar, icon: const Icon(Icons.send_outlined)),
                  ]),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Andamento extends ConsumerWidget {
  const _Andamento({required this.id, required this.r});
  final int id;
  final Relato r;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final hist = ref.watch(historicoProvider(id));
    final itens = <Widget>[
      _Passo(icone: Icons.add_location_alt_outlined, cor: t.colorScheme.primary, titulo: 'Registrada por ${r.autorNome}', sub: dataCurta(r.criadoEm)),
      ...?hist.value?.map((h) {
        final s = statusPorId(h.paraStatus);
        return _Passo(
          icone: s.icone,
          cor: s.cor,
          titulo: '${s.rotulo} (${h.autorNome})',
          sub: [dataCurta(h.criadoEm), if (h.observacao != null) h.observacao!].join('. '),
        );
      }),
    ];
    return Column(children: itens);
  }
}

class _Passo extends StatelessWidget {
  const _Passo({required this.icone, required this.cor, required this.titulo, required this.sub});
  final IconData icone;
  final Color cor;
  final String titulo;
  final String sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: cor.withValues(alpha: .13), borderRadius: BorderRadius.circular(8)), child: Icon(icone, size: 16, color: cor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      );
}

class _Comentarios extends ConsumerWidget {
  const _Comentarios({required this.id});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final lista = ref.watch(comentariosProvider(id));
    return lista.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (e, _) => Text('$e', style: TextStyle(color: t.colorScheme.error)),
      data: (cs) => cs.isEmpty
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum comentário ainda.', style: t.textTheme.bodySmall))
          : Column(children: [
              for (final c in cs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(radius: 16, backgroundColor: t.colorScheme.primaryContainer, foregroundColor: t.colorScheme.onPrimaryContainer, child: Text(c.autorNome.isEmpty ? '?' : c.autorNome[0])),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(c.autorNome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 8),
                          Text(tempoRelativo(c.criadoEm), style: t.textTheme.labelSmall),
                        ]),
                        const SizedBox(height: 2),
                        Text(c.texto, style: t.textTheme.bodyMedium),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }
}
