import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/tema.dart';
import 'data/config.dart';
import 'data/sessao.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final prefs = await SharedPreferences.getInstance();
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'token');
  final usuarioJson = await storage.read(key: 'usuario');

  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sessaoInicialProvider.overrideWithValue(Sessao.deArmazenado(token, usuarioJson)),
      ],
      child: const EcoAlertaApp(),
    ),
  );
}

class EcoAlertaApp extends ConsumerWidget {
  const EcoAlertaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(temaProvider);
    final sessao = ref.watch(sessaoProvider);
    return MaterialApp(
      title: 'EcoAlerta',
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaEscuro,
      themeMode: modo,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: sessao == null ? const LoginScreen() : const HomeShell(),
    );
  }
}
