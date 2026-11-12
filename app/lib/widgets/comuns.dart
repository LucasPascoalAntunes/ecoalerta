import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/categorias.dart';
import '../core/formatadores.dart';
import '../data/api.dart';
import '../data/config.dart';
import '../data/modelos.dart';
import '../data/provedores.dart';
import '../data/tempo_real.dart';

void mostrarSnack(BuildContext context, String msg, {bool erro = false, SnackBarAction? acao}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
      action: acao,
      duration: Duration(seconds: erro ? 5 : 3),
    ));
}

class IconeCategoria extends StatelessWidget {
  const IconeCategoria(this.categoriaId, {super.key, this.tamanho = 44});
  final String categoriaId;
  final double tamanho;
  @override
  Widget build(BuildContext context) {
    final c = categoriaPorId(categoriaId);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: c.cor.withValues(alpha: .13), borderRadius: BorderRadius.circular(tamanho * .24)),
      child: Icon(c.icone, color: c.cor, size: tamanho * .52),
    );
  }
}

class MarcadorCategoria extends StatelessWidget {
  const MarcadorCategoria(this.categoriaId, {super.key, this.opaco = false, this.tamanho = 36});
  final String categoriaId;
  final bool opaco;
  final double tamanho;
  @override
  Widget build(BuildContext context) {
    final c = categoriaPorId(categoriaId);
    return Opacity(
      opacity: opaco ? .5 : 1,
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: c.cor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(c.icone, color: Colors.white, size: tamanho * .52),
      ),
    );
  }
}

class Situacao extends StatelessWidget {
  const Situacao(this.status, {super.key, this.tamanho = 13});
  final String status;
  final double tamanho;
  @override
  Widget build(BuildContext context) {
    final s = statusPorId(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: s.cor, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(s.rotulo, style: TextStyle(color: s.cor, fontWeight: FontWeight.w600, fontSize: tamanho)),
    ]);
  }
}

class NivelGravidade extends StatelessWidget {
  const NivelGravidade(this.gravidade, {super.key, this.comRotulo = true});
  final int gravidade;
  final bool comRotulo;
  @override
  Widget build(BuildContext context) {
    final cor = corGravidade(gravidade);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Container(
          width: 6,
          height: 4.0 + i * 2,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: i <= gravidade ? cor : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      if (comRotulo) ...[
        const SizedBox(width: 6),
        Text(kGravidades[gravidade] ?? '', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    ]);
  }
}

class ItemOcorrencia extends ConsumerWidget {
  const ItemOcorrencia(this.r, {super.key, required this.onTap});
  final Relato r;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final cat = categoriaPorId(r.categoria);
    final base = ref.watch(configProvider).servidorUrl;
    final encerrado = r.status == 'resolvido' || r.status == 'invalido';
    final meta = <String>[
      if (r.bairro != null && r.bairro!.isNotEmpty) r.bairro!,
      if (r.distanciaKm != null) distancia(r.distanciaKm),
      tempoRelativo(r.criadoEm),
    ];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.fotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: urlAbsoluta(base, r.fotoUrl),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, _) => IconeCategoria(r.categoria, tamanho: 56),
                errorWidget: (_, _, _) => IconeCategoria(r.categoria, tamanho: 56),
              ),
            )
          else
            IconeCategoria(r.categoria, tamanho: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.nome.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cat.cor, letterSpacing: .4)),
              const SizedBox(height: 2),
              Text(
                r.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: encerrado ? t.colorScheme.onSurfaceVariant : t.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(meta.join(' · '), style: t.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Situacao(r.status, tamanho: 12),
                const SizedBox(width: 12),
                Icon(Icons.thumb_up_outlined, size: 14, color: r.confirmadoPorMim ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${r.confirmacoes}', style: t.textTheme.bodySmall),
                const SizedBox(width: 12),
                Icon(Icons.mode_comment_outlined, size: 14, color: t.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${r.comentariosQtd}', style: t.textTheme.bodySmall),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right, color: t.colorScheme.outline),
        ]),
      ),
    );
  }
}

class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key, this.acao, this.topo = 20});
  final String texto;
  final Widget? acao;
  final double topo;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, topo, 16, 8),
        child: Row(children: [
          Expanded(child: Text(texto.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: .6))),
          ?acao,
        ]),
      );
}

class Bloco extends StatelessWidget {
  const Bloco({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final borda = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.symmetric(horizontal: BorderSide(color: borda)),
      ),
      padding: padding,
      child: child,
    );
  }
}

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.icone, required this.titulo, this.mensagem, this.acao});
  final IconData icone;
  final String titulo;
  final String? mensagem;
  final Widget? acao;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 44, color: t.colorScheme.outline),
          const SizedBox(height: 12),
          Text(titulo, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          if (mensagem != null) ...[
            const SizedBox(height: 6),
            Text(mensagem!, textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
          if (acao != null) ...[const SizedBox(height: 16), acao!],
        ]),
      ),
    );
  }
}

class ErroCarregar extends StatelessWidget {
  const ErroCarregar(this.erro, {super.key, required this.onTentar});
  final Object erro;
  final VoidCallback onTentar;
  @override
  Widget build(BuildContext context) {
    final api = erro is ApiException ? erro as ApiException : null;
    return EstadoVazio(
      icone: api?.semConexao == true ? Icons.cloud_off_outlined : Icons.error_outline,
      titulo: api?.semConexao == true ? 'Sem conexão com o servidor' : 'Não foi possível carregar',
      mensagem: api?.mensagem ?? erro.toString(),
      acao: OutlinedButton(onPressed: onTentar, child: const Text('Tentar novamente')),
    );
  }
}

class Carregando extends StatelessWidget {
  const Carregando({super.key, this.texto});
  final String? texto;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
          if (texto != null) ...[const SizedBox(height: 12), Text(texto!, style: Theme.of(context).textTheme.bodySmall)],
        ]),
      );
}

class Indicador extends StatelessWidget {
  const Indicador({super.key, required this.titulo, required this.valor, this.cor});
  final String titulo;
  final String valor;
  final Color? cor;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cor ?? t.colorScheme.onSurface, height: 1.1)),
        const SizedBox(height: 4),
        Text(titulo, style: t.textTheme.bodySmall, maxLines: 2),
      ]),
    );
  }
}

class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario(this.texto, {super.key, required this.onPressed, this.carregando = false, this.icone});
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  final IconData? icone;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
        onPressed: carregando ? null : onPressed,
        child: carregando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icone != null) ...[Icon(icone, size: 20), const SizedBox(width: 8)],
                Text(texto),
              ]),
        ),
      );
}

Future<String?> escolherCategoria(BuildContext context, {String? atual, bool permitirTodas = false}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final t = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Tipo de ocorrência', style: t.textTheme.titleMedium),
            ),
            if (permitirTodas)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.layers_outlined, color: t.colorScheme.onSurfaceVariant),
                ),
                title: const Text('Todas as categorias'),
                trailing: (atual == null || atual.isEmpty) ? Icon(Icons.check, color: t.colorScheme.primary) : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
            for (final c in kCategorias)
              ListTile(
                leading: IconeCategoria(c.id, tamanho: 40),
                title: Text(c.nome),
                subtitle: Text(c.descricao, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: atual == c.id ? Icon(Icons.check, color: t.colorScheme.primary) : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ]),
        ),
      );
    },
  );
}

Future<void> mostrarDialogoServidor(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController(text: ref.read(configProvider).servidorUrl);
  final novo = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Servidor'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Endereço', hintText: 'http://192.168.0.10:8080'),
        ),
        const SizedBox(height: 10),
        Text(
          'No emulador use 10.0.2.2. No celular, o IP do computador na mesma rede.',
          style: Theme.of(ctx).textTheme.bodySmall,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
      ],
    ),
  );
  if (novo == null || novo.trim().isEmpty) return;
  await ref.read(configProvider.notifier).setServidor(novo);
  ref.read(tempoRealProvider.notifier).reconectar();
  ref.invalidate(relatosProvider);
  ref.invalidate(estatisticasProvider);
  ref.invalidate(pontosProvider);
  ref.invalidate(healthProvider);
  try {
    final h = await ref.read(apiProvider).health();
    if (context.mounted) mostrarSnack(context, 'Conectado ao servidor (versão ${h['versao']})');
  } on ApiException catch (e) {
    if (context.mounted) mostrarSnack(context, e.mensagem, erro: true);
  }
}
