import 'package:flutter/foundation.dart' show kIsWeb;

Map<String, String> parametrosUrl() {
  if (!kIsWeb) return const {};
  try {
    return Uri.base.queryParameters;
  } catch (_) {
    return const {};
  }
}

const kContasDemo = <String, (String, String)>{
  'ana': ('ana@ecoalerta.app', '123456'),
  'bruno': ('bruno@ecoalerta.app', '123456'),
  'gestor': ('gestor@ecoalerta.app', 'gestor123'),
};
