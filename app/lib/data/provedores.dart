import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'modelos.dart';

final relatosProvider = FutureProvider.autoDispose.family<List<Relato>, FiltroRelatos>(
  (ref, f) => ref.watch(apiProvider).listarRelatos(f),
);

final relatoProvider = FutureProvider.autoDispose.family<Relato, int>(
  (ref, id) => ref.watch(apiProvider).obterRelato(id),
);

final comentariosProvider = FutureProvider.autoDispose.family<List<Comentario>, int>(
  (ref, id) => ref.watch(apiProvider).comentarios(id),
);

final historicoProvider = FutureProvider.autoDispose.family<List<HistoricoStatus>, int>(
  (ref, id) => ref.watch(apiProvider).historico(id),
);

final estatisticasProvider = FutureProvider.autoDispose<Estatisticas>(
  (ref) => ref.watch(apiProvider).estatisticas(),
);

final arProvider = FutureProvider.autoDispose.family<QualidadeAr, (double, double)>(
  (ref, p) => ref.watch(apiProvider).qualidadeAr(p.$1, p.$2),
);

final climaProvider = FutureProvider.autoDispose.family<Clima, (double, double)>(
  (ref, p) => ref.watch(apiProvider).clima(p.$1, p.$2),
);

final pontosProvider = FutureProvider.autoDispose<List<PontoMonitorado>>(
  (ref) => ref.watch(apiProvider).pontos(),
);

final historicoArProvider = FutureProvider.autoDispose.family<HistoricoAr, (double, double)>(
  (ref, p) => ref.watch(apiProvider).historicoAr(lat: p.$1, lon: p.$2),
);

final healthProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(apiProvider).health(),
);
