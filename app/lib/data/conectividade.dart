import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _online(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

final conectividadeProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  yield _online(await c.checkConnectivity());
  await for (final r in c.onConnectivityChanged) {
    yield _online(r);
  }
});
