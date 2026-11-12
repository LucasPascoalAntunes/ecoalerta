import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

class EventoTempoReal {
  const EventoTempoReal({required this.tipo, required this.hora, required this.dados, required this.seq});
  final String tipo;
  final String hora;
  final Map<String, dynamic> dados;
  final int seq;
}

class EstadoTempoReal {
  const EstadoTempoReal({required this.conectado, this.ultimo, this.recebidos = 0, this.tentativa = 0});
  final bool conectado;
  final EventoTempoReal? ultimo;
  final int recebidos;
  final int tentativa;
  EstadoTempoReal copyWith({bool? conectado, EventoTempoReal? ultimo, int? recebidos, int? tentativa}) => EstadoTempoReal(
        conectado: conectado ?? this.conectado,
        ultimo: ultimo ?? this.ultimo,
        recebidos: recebidos ?? this.recebidos,
        tentativa: tentativa ?? this.tentativa,
      );
}

class TempoRealNotifier extends Notifier<EstadoTempoReal> {
  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _sub;
  Timer? _timer;
  int _seq = 0;
  bool _encerrado = false;

  @override
  EstadoTempoReal build() {
    _encerrado = false;
    final url = urlWebSocket(ref.watch(configProvider).servidorUrl);
    ref.onDispose(() {
      _encerrado = true;
      _fechar();
    });
    Future.microtask(() => _conectar(url));
    return const EstadoTempoReal(conectado: false);
  }

  void _fechar() {
    _timer?.cancel();
    _sub?.cancel();
    _canal?.sink.close();
    _canal = null;
    _sub = null;
  }

  Future<void> _conectar(String url) async {
    if (_encerrado) return;
    _fechar();
    try {
      final canal = WebSocketChannel.connect(Uri.parse(url));
      await canal.ready;
      if (_encerrado) {
        canal.sink.close();
        return;
      }
      _canal = canal;
      state = state.copyWith(conectado: true, tentativa: 0);
      _sub = canal.stream.listen(
        (msg) {
          try {
            final j = Map<String, dynamic>.from(jsonDecode(msg as String) as Map);
            final ev = EventoTempoReal(
              tipo: j['tipo']?.toString() ?? '?',
              hora: j['hora']?.toString() ?? '',
              dados: j['dados'] is Map ? Map<String, dynamic>.from(j['dados'] as Map) : {},
              seq: ++_seq,
            );
            state = state.copyWith(ultimo: ev, recebidos: state.recebidos + 1);
          } catch (_) {
          }
        },
        onDone: () => _agendar(url),
        onError: (_) => _agendar(url),
        cancelOnError: true,
      );
    } catch (_) {
      _agendar(url);
    }
  }

  void _agendar(String url) {
    if (_encerrado) return;
    final tentativa = state.tentativa + 1;
    state = state.copyWith(conectado: false, tentativa: tentativa);
    final segundos = min(30, pow(2, min(tentativa, 5)).toInt());
    _timer?.cancel();
    _timer = Timer(Duration(seconds: segundos), () => _conectar(url));
  }

  void reconectar() {
    final url = urlWebSocket(ref.read(configProvider).servidorUrl);
    state = state.copyWith(tentativa: 0);
    _conectar(url);
  }
}

final tempoRealProvider = NotifierProvider<TempoRealNotifier, EstadoTempoReal>(TempoRealNotifier.new);
