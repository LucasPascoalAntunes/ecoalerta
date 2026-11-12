import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/categorias.dart';
import '../../data/api.dart';
import '../../data/conectividade.dart';
import '../../data/fila_offline.dart';
import '../../data/localizacao.dart';
import '../../data/provedores.dart';
import '../../widgets/comuns.dart';

class NovoRelatoScreen extends ConsumerStatefulWidget {
  const NovoRelatoScreen({super.key});
  @override
  ConsumerState<NovoRelatoScreen> createState() => _NovoRelatoScreenState();
}

class _NovoRelatoScreenState extends ConsumerState<NovoRelatoScreen> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _endereco = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _mapa = MapController();
  String? _categoria;
  int _gravidade = 3;
  Uint8List? _foto;
  LatLng? _ponto;
  bool _posicaoReal = false;
  bool _buscandoGps = false;
  bool _buscandoEndereco = false;
  bool _enviando = false;
  Timer? _debounceGeo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _usarGps());
  }

  @override
  void dispose() {
    _debounceGeo?.cancel();
    _titulo.dispose();
    _descricao.dispose();
    _endereco.dispose();
    _bairro.dispose();
    _cidade.dispose();
    super.dispose();
  }

  Future<void> _usarGps() async {
    setState(() => _buscandoGps = true);
    final p = await obterPosicao();
    if (!mounted) return;
    setState(() {
      _ponto = LatLng(p.lat, p.lon);
      _posicaoReal = p.real;
      _buscandoGps = false;
    });
    try {
      _mapa.move(_ponto!, 15);
    } catch (_) {}
    if (p.aviso != null) mostrarSnack(context, p.aviso!);
    _agendarGeocode();
  }

  void _definirPonto(LatLng p) {
    setState(() {
      _ponto = p;
      _posicaoReal = false;
    });
    _agendarGeocode();
  }

  void _agendarGeocode() {
    _debounceGeo?.cancel();
    _debounceGeo = Timer(const Duration(milliseconds: 600), _buscarEndereco);
  }

  Future<void> _buscarEndereco() async {
    final p = _ponto;
    if (p == null) return;
    setState(() => _buscandoEndereco = true);
    try {
      final e = await ref.read(apiProvider).geocode(p.latitude, p.longitude);
      if (!mounted) return;
      _endereco.text = e.endereco;
      _bairro.text = e.bairro ?? '';
      _cidade.text = e.cidade ?? '';
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _buscandoEndereco = false);
    }
  }

  Future<void> _escolherCategoria() async {
    final r = await escolherCategoria(context, atual: _categoria);
    if (r != null && r.isNotEmpty) setState(() => _categoria = r);
  }

  Future<void> _foto_(ImageSource origem) async {
    try {
      final x = await ImagePicker().pickImage(source: origem, maxWidth: 1280, maxHeight: 1280, imageQuality: 72);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() => _foto = bytes);
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Não foi possível carregar a foto', erro: true);
    }
  }

  void _adicionarFoto() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () {
              Navigator.pop(ctx);
              _foto_(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () {
              Navigator.pop(ctx);
              _foto_(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _editarEndereco() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endereço'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _endereco, decoration: const InputDecoration(labelText: 'Endereço'), textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 10),
          TextField(controller: _bairro, decoration: const InputDecoration(labelText: 'Bairro'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: 10),
          TextField(controller: _cidade, decoration: const InputDecoration(labelText: 'Cidade'), textCapitalization: TextCapitalization.words),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto'))],
      ),
    );
    setState(() {});
  }

  Future<void> _enviar() async {
    if (_categoria == null) {
      mostrarSnack(context, 'Escolha o tipo da ocorrência', erro: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_ponto == null) {
      mostrarSnack(context, 'Marque o local no mapa', erro: true);
      return;
    }
    setState(() => _enviando = true);
    final corpo = <String, dynamic>{
      'categoria': _categoria,
      'titulo': _titulo.text.trim(),
      'descricao': _descricao.text.trim(),
      'gravidade': _gravidade,
      'latitude': _ponto!.latitude,
      'longitude': _ponto!.longitude,
      if (_endereco.text.trim().isNotEmpty) 'endereco': _endereco.text.trim(),
      if (_bairro.text.trim().isNotEmpty) 'bairro': _bairro.text.trim(),
      if (_cidade.text.trim().isNotEmpty) 'cidade': _cidade.text.trim(),
      if (_foto != null) 'foto_base64': base64Encode(_foto!),
    };
    final online = ref.read(conectividadeProvider).value ?? true;
    final fila = ref.read(filaOfflineProvider.notifier);
    try {
      if (!online) {
        await fila.adicionar(corpo);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      await ref.read(apiProvider).criarRelato(corpo);
      ref.invalidate(relatosProvider);
      ref.invalidate(estatisticasProvider);
      if (mounted) {
        mostrarSnack(context, 'Ocorrência registrada');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (e.semConexao) {
        await fila.adicionar(corpo);
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        mostrarSnack(context, e.mensagem, erro: true);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cat = _categoria == null ? null : categoriaPorId(_categoria!);
    final enderecoTexto = [
      if (_endereco.text.trim().isNotEmpty) _endereco.text.trim(),
      [_bairro.text.trim(), _cidade.text.trim()].where((e) => e.isNotEmpty).join(', '),
    ].where((e) => e.isNotEmpty).join('\n');

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar ocorrência')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const Rotulo('Tipo de ocorrência', topo: 12),
          Bloco(
            child: ListTile(
              leading: cat == null
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.category_outlined, color: t.colorScheme.onSurfaceVariant),
                    )
                  : IconeCategoria(cat.id),
              title: Text(cat?.nome ?? 'Escolher o tipo', style: TextStyle(fontWeight: FontWeight.w600, color: cat == null ? t.colorScheme.onSurfaceVariant : null)),
              subtitle: cat == null ? null : Text(cat.descricao, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: _escolherCategoria,
            ),
          ),
          const Rotulo('Descrição'),
          Bloco(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(children: [
              TextFormField(
                controller: _titulo,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Título', hintText: 'Ex.: Rua alagada em frente à escola'),
                validator: (v) => (v ?? '').trim().length < 5 ? 'Escreva um título com pelo menos 5 caracteres' : null,
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _descricao,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'O que está acontecendo', alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().length < 10 ? 'Descreva com pelo menos 10 caracteres' : null,
              ),
              const SizedBox(height: 4),
              Row(children: [
                Text('Gravidade', style: t.textTheme.labelLarge),
                const Spacer(),
                Text(kGravidades[_gravidade] ?? '', style: TextStyle(color: corGravidade(_gravidade), fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                for (var g = 1; g <= 5; g++) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _gravidade = g),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: g == _gravidade ? corGravidade(g) : t.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: g == _gravidade ? corGravidade(g) : t.colorScheme.outlineVariant),
                        ),
                        child: Text('$g', style: TextStyle(fontWeight: FontWeight.w700, color: g == _gravidade ? Colors.white : t.colorScheme.onSurface)),
                      ),
                    ),
                  ),
                  if (g < 5) const SizedBox(width: 6),
                ],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Text('Baixa', style: t.textTheme.labelSmall),
                const Spacer(),
                Text('Crítica', style: t.textTheme.labelSmall),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
          const Rotulo('Foto'),
          Bloco(
            padding: const EdgeInsets.all(16),
            child: _foto == null
                ? OutlinedButton.icon(onPressed: _adicionarFoto, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Adicionar foto'))
                : Column(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_foto!, height: 200, width: double.infinity, fit: BoxFit.cover)),
                    const SizedBox(height: 8),
                    Row(children: [
                      TextButton.icon(onPressed: _adicionarFoto, icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Trocar')),
                      TextButton.icon(
                        onPressed: () => setState(() => _foto = null),
                        style: TextButton.styleFrom(foregroundColor: t.colorScheme.error),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remover'),
                      ),
                    ]),
                  ]),
          ),
          Rotulo(
            'Local',
            acao: TextButton.icon(
              onPressed: _buscandoGps ? null : _usarGps,
              icon: _buscandoGps
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 16),
              label: const Text('Usar minha localização'),
            ),
          ),
          Bloco(
            child: Column(children: [
              SizedBox(
                height: 220,
                child: FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: _ponto ?? const LatLng(kLatPadrao, kLonPadrao),
                    initialZoom: 14,
                    onTap: (_, p) => _definirPonto(p),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'br.com.ecoalerta.ecoalerta'),
                    if (_ponto != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _ponto!,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on, color: cat?.cor ?? t.colorScheme.primary, size: 40),
                        ),
                      ]),
                  ],
                ),
              ),
              ListTile(
                leading: _buscandoEndereco
                    ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.place_outlined),
                title: Text(enderecoTexto.isEmpty ? 'Toque no mapa para marcar o local' : enderecoTexto, style: const TextStyle(fontSize: 14)),
                subtitle: _ponto == null
                    ? null
                    : Text(_posicaoReal ? 'Posição do GPS. Toque no mapa para ajustar.' : 'Local marcado no mapa. Toque para ajustar.'),
                trailing: IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar endereço', onPressed: _editarEndereco),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: BotaoPrimario('Enviar ocorrência', onPressed: _enviar, carregando: _enviando, icone: Icons.send_outlined),
          ),
        ]),
      ),
    );
  }
}
