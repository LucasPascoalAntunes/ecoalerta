import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categorias.dart';
import '../../data/config.dart';
import '../../data/localizacao.dart';
import '../../data/modelos.dart';
import '../../data/provedores.dart';
import '../../widgets/comuns.dart';
import '../relato/detalhe_relato_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _busca = TextEditingController();
  Timer? _debounce;
  String _termo = '';
  String? _categoria;
  String? _status;
  bool _perto = false;

  int get _filtrosAtivos => (_categoria == null ? 0 : 1) + (_status == null ? 0 : 1);

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _termo = v.trim()));
  }

  Future<void> _filtros() async {
    var categoria = _categoria;
    var status = _status;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(children: [
                Expanded(child: Text('Filtros', style: Theme.of(ctx).textTheme.titleMedium)),
                TextButton(
                  onPressed: () => setSheet(() {
                    categoria = null;
                    status = null;
                  }),
                  child: const Text('Limpar'),
                ),
              ]),
            ),
            ListTile(
              leading: categoria == null ? const Icon(Icons.layers_outlined) : IconeCategoria(categoria!, tamanho: 36),
              title: const Text('Categoria'),
              subtitle: Text(categoria == null ? 'Todas' : categoriaPorId(categoria!).nome),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final r = await escolherCategoria(ctx, atual: categoria, permitirTodas: true);
                if (r != null) setSheet(() => categoria = r.isEmpty ? null : r);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Situação', style: Theme.of(ctx).textTheme.labelLarge)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('Todas'), selected: status == null, onSelected: (_) => setSheet(() => status = null)),
                for (final s in kStatus)
                  ChoiceChip(label: Text(s.rotulo), selected: status == s.id, onSelected: (_) => setSheet(() => status = s.id)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: BotaoPrimario('Aplicar', onPressed: () => Navigator.pop(ctx)),
            ),
          ]),
        ),
      ),
    );
    setState(() {
      _categoria = categoria;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pos = ref.watch(posicaoProvider).value ?? kPosicaoPadrao;
    final raio = ref.watch(configProvider).raioKm;
    final filtro = (
      categoria: _categoria,
      status: _status,
      busca: _termo.isEmpty ? null : _termo,
      lat: pos.lat,
      lon: pos.lon,
      raioKm: _perto ? raio : null,
      ordenar: _perto ? 'distancia' : null,
      meus: false,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocorrências'),
        actions: [IconButton(tooltip: 'Atualizar', onPressed: () => ref.invalidate(relatosProvider), icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Container(
          color: t.colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(children: [
            TextField(
              controller: _busca,
              onChanged: _aoDigitar,
              decoration: InputDecoration(
                hintText: 'Buscar por título, bairro ou descrição',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                fillColor: t.colorScheme.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                suffixIcon: _termo.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busca.clear();
                          setState(() => _termo = '');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              ActionChip(
                avatar: Icon(Icons.tune, size: 16, color: _filtrosAtivos > 0 ? Colors.white : t.colorScheme.onSurface),
                label: Text(_filtrosAtivos > 0 ? 'Filtros ($_filtrosAtivos)' : 'Filtros'),
                labelStyle: TextStyle(color: _filtrosAtivos > 0 ? Colors.white : t.colorScheme.onSurface),
                backgroundColor: _filtrosAtivos > 0 ? t.colorScheme.primary : null,
                side: _filtrosAtivos > 0 ? BorderSide(color: t.colorScheme.primary) : null,
                onPressed: _filtros,
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: Icon(Icons.near_me_outlined, size: 16, color: _perto ? Colors.white : t.colorScheme.onSurface),
                label: Text('Perto de mim (${raio.toStringAsFixed(0)} km)'),
                labelStyle: TextStyle(color: _perto ? Colors.white : t.colorScheme.onSurface),
                selected: _perto,
                onSelected: (v) => setState(() => _perto = v),
              ),
            ]),
          ]),
        ),
        const Divider(),
        Expanded(child: ListaRelatos(filtro: filtro)),
      ]),
    );
  }
}

class ListaRelatos extends ConsumerWidget {
  const ListaRelatos({super.key, required this.filtro, this.vazioTitulo = 'Nenhuma ocorrência encontrada'});
  final FiltroRelatos filtro;
  final String vazioTitulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatos = ref.watch(relatosProvider(filtro));
    return relatos.when(
      loading: () => const Carregando(),
      error: (e, _) => ErroCarregar(e, onTentar: () => ref.invalidate(relatosProvider(filtro))),
      data: (lista) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(relatosProvider(filtro)),
        child: lista.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 320,
                  child: EstadoVazio(icone: Icons.inbox_outlined, titulo: vazioTitulo, mensagem: 'Tente outros filtros ou registre uma nova ocorrência.'),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const Divider(indent: 16),
                itemBuilder: (_, i) => ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: ItemOcorrencia(
                    lista[i],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheRelatoScreen(id: lista[i].id))),
                  ),
                ),
              ),
      ),
    );
  }
}
