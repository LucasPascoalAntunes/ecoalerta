import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'modelos.dart';

class Sessao {
  const Sessao({required this.token, required this.usuario});
  final String token;
  final Usuario usuario;
  bool get gestor => usuario.gestor;

  static Sessao? deArmazenado(String? token, String? usuarioJson) {
    if (token == null || usuarioJson == null) return null;
    try {
      return Sessao(token: token, usuario: Usuario.fromJson(Map<String, dynamic>.from(jsonDecode(usuarioJson) as Map)));
    } catch (_) {
      return null;
    }
  }
}

final sessaoInicialProvider = Provider<Sessao?>((_) => null);

class SessaoNotifier extends Notifier<Sessao?> {
  static const _storage = FlutterSecureStorage();

  @override
  Sessao? build() => ref.read(sessaoInicialProvider);

  Future<void> _guardar(String token, Usuario u) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'usuario', value: jsonEncode(u.toJson()));
    state = Sessao(token: token, usuario: u);
  }

  Future<void> login(String email, String senha) async {
    final r = await ref.read(apiProvider).login(email, senha);
    await _guardar(r.token, r.usuario);
  }

  Future<void> registrar(String nome, String email, String senha) async {
    final r = await ref.read(apiProvider).registrar(nome, email, senha);
    await _guardar(r.token, r.usuario);
  }

  Future<void> revalidar() async {
    if (state == null) return;
    try {
      final u = await ref.read(apiProvider).eu();
      await _guardar(state!.token, u);
    } on ApiException catch (e) {
      if (e.naoAutenticado) await sair();
    }
  }

  Future<void> sair() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'usuario');
    state = null;
  }
}

final sessaoProvider = NotifierProvider<SessaoNotifier, Sessao?>(SessaoNotifier.new);
