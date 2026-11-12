import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider é sobrescrito no main()'),
);

String get kServidorPadrao =>
    (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) ? 'http://localhost:8080' : 'http://10.0.2.2:8080';

class Config {
  const Config({required this.servidorUrl, required this.tema, required this.raioKm});
  final String servidorUrl;
  final ThemeMode tema;
  final double raioKm;

  Config copyWith({String? servidorUrl, ThemeMode? tema, double? raioKm}) => Config(
        servidorUrl: servidorUrl ?? this.servidorUrl,
        tema: tema ?? this.tema,
        raioKm: raioKm ?? this.raioKm,
      );
}

class ConfigNotifier extends Notifier<Config> {
  @override
  Config build() {
    final p = ref.watch(prefsProvider);
    return Config(
      servidorUrl: p.getString('servidor_url') ?? kServidorPadrao,
      tema: ThemeMode.values[(p.getInt('tema') ?? 0).clamp(0, 2)],
      raioKm: p.getDouble('raio_km') ?? 10,
    );
  }

  Future<void> setServidor(String url) async {
    var limpo = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!limpo.startsWith('http')) limpo = 'http://$limpo';
    await ref.read(prefsProvider).setString('servidor_url', limpo);
    state = state.copyWith(servidorUrl: limpo);
  }

  Future<void> setTema(ThemeMode m) async {
    await ref.read(prefsProvider).setInt('tema', m.index);
    state = state.copyWith(tema: m);
  }

  Future<void> setRaio(double km) async {
    await ref.read(prefsProvider).setDouble('raio_km', km);
    state = state.copyWith(raioKm: km);
  }
}

final configProvider = NotifierProvider<ConfigNotifier, Config>(ConfigNotifier.new);
final temaProvider = Provider<ThemeMode>((ref) => ref.watch(configProvider).tema);

String urlWebSocket(String base) {
  final u = Uri.parse(base);
  return u.replace(scheme: u.scheme == 'https' ? 'wss' : 'ws', path: '/ws').toString();
}

String urlAbsoluta(String base, String? caminho) {
  if (caminho == null || caminho.isEmpty) return '';
  if (caminho.startsWith('http')) return caminho;
  return '$base$caminho';
}
