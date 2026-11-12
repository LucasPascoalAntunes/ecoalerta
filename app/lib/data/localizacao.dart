import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class Posicao {
  const Posicao({required this.lat, required this.lon, required this.real, this.aviso});
  final double lat;
  final double lon;
  final bool real;
  final String? aviso;
}

const kLatPadrao = -23.5505;
const kLonPadrao = -46.6333;
const kPosicaoPadrao = Posicao(lat: kLatPadrao, lon: kLonPadrao, real: false, aviso: 'Usando localização padrão (São Paulo)');

bool _noBrasil(double lat, double lon) => lat >= -34 && lat <= 6 && lon >= -74 && lon <= -34;

Future<Posicao> obterPosicao() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const Posicao(lat: kLatPadrao, lon: kLonPadrao, real: false, aviso: 'GPS desligado - usando São Paulo');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return const Posicao(lat: kLatPadrao, lon: kLonPadrao, real: false, aviso: 'Permissão de localização negada - usando São Paulo');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
    );
    if (!_noBrasil(p.latitude, p.longitude)) {
      return const Posicao(lat: kLatPadrao, lon: kLonPadrao, real: false, aviso: 'GPS fora do Brasil (emulador) - usando São Paulo');
    }
    return Posicao(lat: p.latitude, lon: p.longitude, real: true);
  } catch (_) {
    final ultima = await Geolocator.getLastKnownPosition().catchError((_) => null);
    if (ultima != null && _noBrasil(ultima.latitude, ultima.longitude)) {
      return Posicao(lat: ultima.latitude, lon: ultima.longitude, real: true, aviso: 'Última posição conhecida');
    }
    return const Posicao(lat: kLatPadrao, lon: kLonPadrao, real: false, aviso: 'Não foi possível obter o GPS - usando São Paulo');
  }
}

final posicaoProvider = FutureProvider<Posicao>((ref) => obterPosicao());
