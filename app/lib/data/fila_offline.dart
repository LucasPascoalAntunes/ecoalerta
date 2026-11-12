import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'config.dart';

class RelatoPendente {
  const RelatoPendente({required this.idLocal, required this.corpo, required this.criadoEm, this.erro});
  final String idLocal;
  final Map<String, dynamic> corpo;
  final String criadoEm;
  final String? erro;

  String get titulo => corpo['titulo']?.toString() ?? '';
  String get categoria => corpo['categoria']?.toString() ?? 'outro';
  bool get temFoto => (corpo['foto_base64']?.toString() ?? '').isNotEmpty;

  Map<String, dynamic> toJson() => {'idLocal': idLocal, 'corpo': corpo, 'criadoEm': criadoEm, 'erro': erro};
  factory RelatoPendente.fromJson(Map<String, dynamic> j) => RelatoPendente(
        idLocal: j['idLocal'] as String,
        corpo: Map<String, dynamic>.from(j['corpo'] as Map),
        criadoEm: j['criadoEm'] as String,
        erro: j['erro'] as String?,
      );
  RelatoPendente comErro(String? e) => RelatoPendente(idLocal: idLocal, corpo: corpo, criadoEm: criadoEm, erro: e);
}

class FilaOffline {
  const FilaOffline({required this.itens, this.sincronizando = false, this.ultimaMensagem});
  final List<RelatoPendente> itens;
  final bool sincronizando;
  final String? ultimaMensagem;
  int get tamanho => itens.length;
  FilaOffline copyWith({List<RelatoPendente>? itens, bool? sincronizando, String? ultimaMensagem}) =>
      FilaOffline(itens: itens ?? this.itens, sincronizando: sincronizando ?? this.sincronizando, ultimaMensagem: ultimaMensagem);
}

class FilaOfflineNotifier extends Notifier<FilaOffline> {
  static const _chave = 'fila_relatos';

  @override
  FilaOffline build() {
    final bruto = ref.watch(prefsProvider).getString(_chave);
    if (bruto == null) return const FilaOffline(itens: []);
    try {
      final lista = (jsonDecode(bruto) as List).map((e) => RelatoPendente.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return FilaOffline(itens: lista);
    } catch (_) {
      return const FilaOffline(itens: []);
    }
  }

  Future<void> _persistir(List<RelatoPendente> itens) async {
    await ref.read(prefsProvider).setString(_chave, jsonEncode(itens.map((e) => e.toJson()).toList()));
  }

  Future<void> adicionar(Map<String, dynamic> corpo) async {
    final agora = DateTime.now().toUtc().toIso8601String();
    final item = RelatoPendente(
      idLocal: '${DateTime.now().microsecondsSinceEpoch}',
      corpo: {...corpo, 'criado_offline_em': agora},
      criadoEm: agora,
    );
    final itens = [...state.itens, item];
    await _persistir(itens);
    state = state.copyWith(itens: itens, ultimaMensagem: 'Relato guardado para envio quando houver conexão.');
  }

  Future<void> remover(String idLocal) async {
    final itens = state.itens.where((e) => e.idLocal != idLocal).toList();
    await _persistir(itens);
    state = state.copyWith(itens: itens);
  }

  Future<int> sincronizar() async {
    if (state.sincronizando || state.itens.isEmpty) return 0;
    state = state.copyWith(sincronizando: true);
    final api = ref.read(apiProvider);
    var enviados = 0;
    var itens = [...state.itens];
    for (final item in [...itens]) {
      try {
        await api.criarRelato(item.corpo);
        itens.removeWhere((e) => e.idLocal == item.idLocal);
        enviados++;
      } on ApiException catch (e) {
        if (e.semConexao) {
          break;
        }
        itens = itens.map((x) => x.idLocal == item.idLocal ? x.comErro(e.mensagem) : x).toList();
      }
    }
    await _persistir(itens);
    final msg = enviados > 0
        ? '$enviados relato(s) sincronizado(s) com o servidor.'
        : (itens.isEmpty ? null : 'Não foi possível sincronizar agora.');
    state = FilaOffline(itens: itens, sincronizando: false, ultimaMensagem: msg);
    return enviados;
  }
}

final filaOfflineProvider = NotifierProvider<FilaOfflineNotifier, FilaOffline>(FilaOfflineNotifier.new);
