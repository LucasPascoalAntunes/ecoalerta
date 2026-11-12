import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/categorias.dart';
import '../../core/formatadores.dart';
import '../../data/localizacao.dart';
import '../../data/modelos.dart';
import '../../data/provedores.dart';
import '../../widgets/comuns.dart';
import '../relato/detalhe_relato_screen.dart';

class MapaScreen extends ConsumerStatefulWidget {
  const MapaScreen({super.key});
  @override
  ConsumerState<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends ConsumerState<MapaScreen> {
  final _ctrl = MapController();
  String? _categoria;
  bool _somenteAbertas = false;
  bool _centralizou = false;

  int get _filtrosAtivos => (_categoria == null ? 0 : 1) + (_somenteAbertas ? 1 : 0);

  void _centralizar(Posicao p, {double zoom = 12}) {
    try {
      _ctrl.move(LatLng(p.lat, p.lon), zoom);
    } catch (_) {}
  }

  void _abrir(Relato r) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheRelatoScreen(id: r.id)));
  }

  Future<void> _filtros() async {
    var categoria = _categoria;
    var abertas = _somenteAbertas;
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
                    abertas = false;
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
            SwitchListTile(
              secondary: const Icon(Icons.error_outline),
              title: const Text('Somente em aberto'),
              value: abertas,
              onChanged: (v) => setSheet(() => abertas = v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: BotaoPrimario('Aplicar', onPressed: () => Navigator.pop(ctx)),
            ),
          ]),
        ),
      ),
    );
    setState(() {
      _categoria = categoria;
      _somenteAbertas = abertas;
    });
  }

  void _resumo(Relato r) {
    final t = Theme.of(context);
    final cat = categoriaPorId(r.categoria);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconeCategoria(r.categoria, tamanho: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat.nome.toUpperCase(), style: TextStyle(color: cat.cor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: .4)),
                  const SizedBox(height: 2),
                  Text(r.titulo, style: t.textTheme.titleMedium),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text(r.descricao, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.place_outlined, size: 16, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(r.endereco ?? r.local, style: t.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Situacao(r.status),
              const SizedBox(width: 14),
              NivelGravidade(r.gravidade),
              const Spacer(),
              Text(tempoRelativo(r.criadoEm), style: t.textTheme.bodySmall),
            ]),
            const SizedBox(height: 16),
            BotaoPrimario('Ver ocorrência', onPressed: () {
              Navigator.pop(ctx);
              _abrir(r);
            }),
          ]),
        ),
      ),
    );
  }

  void _legenda() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Legenda', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final c in kCategorias)
            ListTile(dense: true, leading: MarcadorCategoria(c.id, tamanho: 30), title: Text(c.nome), subtitle: Text(c.descricao, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pos = ref.watch(posicaoProvider).value ?? kPosicaoPadrao;
    ref.listen(posicaoProvider, (_, next) {
      final p = next.value;
      if (p != null && !_centralizou) {
        _centralizou = true;
        _centralizar(p);
      }
    });

    final filtro = (
      categoria: _categoria,
      status: _somenteAbertas ? 'aberto' : null,
      busca: null,
      lat: pos.lat,
      lon: pos.lon,
      raioKm: null,
      ordenar: null,
      meus: false,
    );
    final relatos = ref.watch(relatosProvider(filtro));
    final lista = relatos.value ?? const <Relato>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _filtros,
            icon: Badge(
              isLabelVisible: _filtrosAtivos > 0,
              label: Text('$_filtrosAtivos'),
              child: const Icon(Icons.tune),
            ),
          ),
          IconButton(tooltip: 'Legenda', onPressed: _legenda, icon: const Icon(Icons.info_outline)),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _ctrl,
          options: MapOptions(initialCenter: LatLng(pos.lat, pos.lon), initialZoom: 12, minZoom: 3, maxZoom: 19),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.com.ecoalerta.ecoalerta',
            ),
            MarkerLayer(markers: [
              if (pos.real)
                Marker(
                  point: LatLng(pos.lat, pos.lon),
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
                    ),
                  ),
                ),
              for (final r in lista)
                Marker(
                  point: LatLng(r.latitude, r.longitude),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => _resumo(r),
                    child: MarcadorCategoria(r.categoria, opaco: r.status == 'resolvido' || r.status == 'invalido'),
                  ),
                ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: FloatingActionButton.small(
            heroTag: 'gps',
            backgroundColor: t.colorScheme.surface,
            foregroundColor: t.colorScheme.onSurface,
            tooltip: 'Minha localização',
            onPressed: () {
              ref.invalidate(posicaoProvider);
              _centralizar(pos, zoom: 14);
            },
            child: const Icon(Icons.my_location),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Material(
            color: t.colorScheme.surface,
            elevation: 2,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (relatos.isLoading) ...[
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                ],
                Text(
                  relatos.hasError ? 'Servidor indisponível' : (lista.length == 1 ? '1 ocorrência' : '${lista.length} ocorrências'),
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface),
                ),
                if (!pos.real) ...[
                  const SizedBox(width: 6),
                  Tooltip(message: pos.aviso ?? '', child: Icon(Icons.gps_off, size: 14, color: t.colorScheme.onSurfaceVariant)),
                ],
              ]),
            ),
          ),
        ),
        if (relatos.hasError)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: t.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.cloud_off_outlined, color: t.colorScheme.onErrorContainer),
                title: Text('${relatos.error}', style: TextStyle(color: t.colorScheme.onErrorContainer, fontSize: 12)),
                trailing: TextButton(onPressed: () => ref.invalidate(relatosProvider), child: const Text('Tentar')),
              ),
            ),
          ),
      ]),
    );
  }
}
