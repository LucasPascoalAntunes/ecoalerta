import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categorias.dart';
import '../../data/conectividade.dart';
import '../../data/deep_link.dart';
import '../../data/fila_offline.dart';
import '../../data/provedores.dart';
import '../../data/sessao.dart';
import '../../data/tempo_real.dart';
import '../../widgets/comuns.dart';
import '../ambiente/ambiente_screen.dart';
import '../feed/feed_screen.dart';
import '../mapa/mapa_screen.dart';
import '../painel/painel_screen.dart';
import '../perfil/perfil_screen.dart';
import '../relato/detalhe_relato_screen.dart';
import '../relato/novo_relato_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    final params = parametrosUrl();
    _aba = (int.tryParse(params['aba'] ?? '') ?? 0).clamp(0, 4);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessaoProvider.notifier).revalidar();
      ref.read(filaOfflineProvider.notifier).sincronizar();
      ref.read(tempoRealProvider);
      final id = int.tryParse(params['relato'] ?? '');
      if (id != null) _abrirDetalhe(id);
      if (params['novo'] != null) _novo();
    });
  }

  void _abrirDetalhe(int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheRelatoScreen(id: id)));
  }

  void _novo() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NovoRelatoScreen()));
  }

  void _tratarEvento(EventoTempoReal ev) {
    final meuId = ref.read(sessaoProvider)?.usuario.id;
    final d = ev.dados;
    switch (ev.tipo) {
      case 'relato_criado':
        ref.invalidate(relatosProvider);
        ref.invalidate(estatisticasProvider);
        final id = (d['id'] as num?)?.toInt();
        if (d['usuario_id'] != meuId && id != null) {
          final cat = categoriaPorId(d['categoria']?.toString() ?? 'outro');
          final onde = d['bairro']?.toString();
          mostrarSnack(
            context,
            onde == null || onde.isEmpty ? 'Nova ocorrência: ${cat.nome}' : 'Nova ocorrência: ${cat.nome} em $onde',
            acao: SnackBarAction(label: 'Ver', onPressed: () => _abrirDetalhe(id)),
          );
        }
      case 'status_alterado':
        ref.invalidate(relatosProvider);
        ref.invalidate(relatoProvider);
        ref.invalidate(historicoProvider);
        ref.invalidate(estatisticasProvider);
        final r = d['relato'] is Map ? Map<String, dynamic>.from(d['relato'] as Map) : null;
        if (r != null && r['usuario_id'] == meuId) {
          final s = statusPorId(r['status']?.toString() ?? 'aberto');
          mostrarSnack(context, 'Sua ocorrência "${r['titulo']}" agora está ${s.rotulo.toLowerCase()}');
        }
      case 'relato_confirmado':
        ref.invalidate(relatosProvider);
        ref.invalidate(relatoProvider);
        ref.invalidate(estatisticasProvider);
      case 'comentario_criado':
        ref.invalidate(comentariosProvider);
        ref.invalidate(relatoProvider);
        ref.invalidate(relatosProvider);
      case 'relato_excluido':
        ref.invalidate(relatosProvider);
        ref.invalidate(estatisticasProvider);
      case 'amostra_ar':
        ref.invalidate(pontosProvider);
        ref.invalidate(historicoArProvider);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tempoRealProvider, (prev, next) {
      final ev = next.ultimo;
      if (ev == null || ev.seq == prev?.ultimo?.seq) return;
      _tratarEvento(ev);
    });
    ref.listen(conectividadeProvider, (prev, next) {
      if (next.value == true && prev?.value == false) {
        ref.read(filaOfflineProvider.notifier).sincronizar();
        ref.read(tempoRealProvider.notifier).reconectar();
        ref.invalidate(relatosProvider);
      }
    });
    ref.listen(filaOfflineProvider, (prev, next) {
      final m = next.ultimaMensagem;
      if (m != null && m != prev?.ultimaMensagem) mostrarSnack(context, m);
    });

    final online = ref.watch(conectividadeProvider).value ?? true;
    final fila = ref.watch(filaOfflineProvider);
    final tempoReal = ref.watch(tempoRealProvider);
    final t = Theme.of(context);

    return Scaffold(
      body: Column(children: [
        if (!online)
          _Aviso(cor: t.colorScheme.inverseSurface, corTexto: t.colorScheme.onInverseSurface, icone: Icons.cloud_off_outlined, texto: 'Sem conexão. Novos registros ficam salvos no aparelho.'),
        if (online && fila.tamanho > 0)
          _Aviso(
            cor: t.colorScheme.secondaryContainer,
            corTexto: t.colorScheme.onSecondaryContainer,
            icone: Icons.upload_outlined,
            texto: fila.tamanho == 1 ? '1 registro aguardando envio' : '${fila.tamanho} registros aguardando envio',
            acao: TextButton(
              onPressed: fila.sincronizando ? null : () => ref.read(filaOfflineProvider.notifier).sincronizar(),
              style: TextButton.styleFrom(foregroundColor: t.colorScheme.onSecondaryContainer),
              child: Text(fila.sincronizando ? 'Enviando' : 'Enviar'),
            ),
          ),
        if (online && !tempoReal.conectado && tempoReal.tentativa > 1)
          _Aviso(cor: t.colorScheme.surfaceContainerHigh, corTexto: t.colorScheme.onSurfaceVariant, icone: Icons.sync_problem_outlined, texto: 'Reconectando ao servidor'),
        Expanded(
          child: IndexedStack(index: _aba, children: const [
            MapaScreen(),
            FeedScreen(),
            AmbienteScreen(),
            PainelScreen(),
            PerfilScreen(),
          ]),
        ),
      ]),
      floatingActionButton: _aba <= 1
          ? FloatingActionButton.extended(onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Registrar'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.format_list_bulleted), selectedIcon: Icon(Icons.format_list_bulleted), label: 'Ocorrências'),
          NavigationDestination(icon: Icon(Icons.air), selectedIcon: Icon(Icons.air), label: 'Ar e clima'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Resumo'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.cor, required this.corTexto, required this.icone, required this.texto, this.acao});
  final Color cor;
  final Color corTexto;
  final IconData icone;
  final String texto;
  final Widget? acao;
  @override
  Widget build(BuildContext context) => Material(
        color: cor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Icon(icone, size: 18, color: corTexto),
              const SizedBox(width: 10),
              Expanded(child: Text(texto, style: TextStyle(color: corTexto, fontSize: 13))),
              ?acao,
            ]),
          ),
        ),
      );
}
