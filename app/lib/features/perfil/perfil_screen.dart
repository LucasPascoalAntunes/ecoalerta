import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatadores.dart';
import '../../data/config.dart';
import '../../data/fila_offline.dart';
import '../../data/provedores.dart';
import '../../data/sessao.dart';
import '../../data/tempo_real.dart';
import '../../widgets/comuns.dart';
import '../feed/feed_screen.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final sessao = ref.watch(sessaoProvider);
    final config = ref.watch(configProvider);
    final fila = ref.watch(filaOfflineProvider);
    final tempoReal = ref.watch(tempoRealProvider);
    final health = ref.watch(healthProvider);
    final u = sessao?.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Bloco(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: t.colorScheme.primaryContainer,
              foregroundColor: t.colorScheme.onPrimaryContainer,
              child: Text(u == null || u.nome.isEmpty ? '?' : u.nome[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u?.nome ?? '', style: t.textTheme.titleMedium),
                Text(u?.email ?? '', style: t.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(u?.gestor == true ? 'Gestor ambiental' : 'Cidadão', style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Bloco(
          child: ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Meus registros'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Meus registros')),
                body: const ListaRelatos(
                  filtro: (categoria: null, status: null, busca: null, lat: null, lon: null, raioKm: null, ordenar: null, meus: true),
                  vazioTitulo: 'Você ainda não registrou ocorrências',
                ),
              ),
            )),
          ),
        ),
        if (fila.tamanho > 0) ...[
          Rotulo(
            'Aguardando envio (${fila.tamanho})',
            acao: TextButton(
              onPressed: fila.sincronizando ? null : () => ref.read(filaOfflineProvider.notifier).sincronizar(),
              child: Text(fila.sincronizando ? 'Enviando' : 'Enviar agora'),
            ),
          ),
          Bloco(
            child: Column(children: [
              for (var i = 0; i < fila.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 16),
                ListTile(
                  leading: IconeCategoria(fila.itens[i].categoria, tamanho: 40),
                  title: Text(fila.itens[i].titulo),
                  subtitle: Text(
                    fila.itens[i].erro ?? 'Criado ${tempoRelativo(fila.itens[i].criadoEm)}${fila.itens[i].temFoto ? ', com foto' : ''}',
                    style: TextStyle(color: fila.itens[i].erro != null ? t.colorScheme.error : null),
                  ),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Descartar', onPressed: () => ref.read(filaOfflineProvider.notifier).remover(fila.itens[i].idLocal)),
                ),
              ],
            ]),
          ),
        ],
        const Rotulo('Configurações'),
        Bloco(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Servidor'),
              subtitle: Text(config.servidorUrl),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => mostrarDialogoServidor(context, ref),
            ),
            const Divider(indent: 16),
            ListTile(
              leading: const Icon(Icons.radar),
              title: const Text('Raio de busca'),
              subtitle: Text('${config.raioKm.toStringAsFixed(0)} km ao redor da sua posição'),
              trailing: SizedBox(
                width: 140,
                child: Slider(
                  value: config.raioKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${config.raioKm.toStringAsFixed(0)} km',
                  onChanged: (v) => ref.read(configProvider.notifier).setRaio(v),
                ),
              ),
            ),
            const Divider(indent: 16),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Tema'),
              trailing: DropdownButton<ThemeMode>(
                value: config.tema,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Automático')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
                ],
                onChanged: (m) => m == null ? null : ref.read(configProvider.notifier).setTema(m),
              ),
            ),
          ]),
        ),
        const Rotulo('Conexão'),
        Bloco(
          child: Column(children: [
            health.when(
              loading: () => const ListTile(leading: SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2))), title: Text('Verificando o servidor')),
              error: (e, _) => ListTile(
                leading: Icon(Icons.cloud_off_outlined, color: t.colorScheme.error),
                title: const Text('Servidor fora do ar'),
                subtitle: Text('$e'),
                trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(healthProvider)),
              ),
              data: (h) => ListTile(
                leading: Icon(Icons.cloud_done_outlined, color: t.colorScheme.primary),
                title: Text('Servidor ativo, versão ${h['versao']}'),
                subtitle: Text('${h['requisicoes_atendidas']} requisições atendidas. ${h['clientes_websocket']} aplicativos conectados.'),
                trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(healthProvider)),
              ),
            ),
            const Divider(indent: 16),
            ListTile(
              leading: Icon(tempoReal.conectado ? Icons.bolt : Icons.bolt_outlined, color: tempoReal.conectado ? t.colorScheme.primary : t.colorScheme.error),
              title: Text(tempoReal.conectado ? 'Atualizações em tempo real ativas' : 'Sem atualizações em tempo real'),
              subtitle: Text(tempoReal.recebidos == 1 ? '1 evento recebido' : '${tempoReal.recebidos} eventos recebidos'),
              trailing: IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reconectar', onPressed: () => ref.read(tempoRealProvider.notifier).reconectar()),
            ),
            const Divider(indent: 16),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Painel do servidor'),
              subtitle: Text('${config.servidorUrl}/'),
              onTap: () => launchUrl(Uri.parse('${config.servidorUrl}/'), mode: LaunchMode.externalApplication),
            ),
          ]),
        ),
        const Rotulo('Sobre'),
        Bloco(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(
            'EcoAlerta 1.0. Trabalho de Atividades Práticas Supervisionadas do curso de Ciência da Computação da UNIP Santos, 2026. '
            'Dados de qualidade do ar e clima: Open-Meteo. Mapas e endereços: OpenStreetMap.',
            style: t.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: OutlinedButton(
            onPressed: () => ref.read(sessaoProvider.notifier).sair(),
            style: OutlinedButton.styleFrom(foregroundColor: t.colorScheme.error),
            child: const Text('Sair da conta'),
          ),
        ),
      ]),
    );
  }
}
