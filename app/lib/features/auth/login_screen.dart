import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/config.dart';
import '../../data/deep_link.dart';
import '../../data/sessao.dart';
import '../../widgets/comuns.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _cadastro = false;
  bool _carregando = false;
  bool _verSenha = false;

  @override
  void initState() {
    super.initState();
    final conta = kContasDemo[parametrosUrl()['entrar']];
    if (conta != null) {
      _email.text = conta.$1;
      _senha.text = conta.$2;
      WidgetsBinding.instance.addPostFrameCallback((_) => _enviar());
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _carregando = true);
    try {
      final n = ref.read(sessaoProvider.notifier);
      if (_cadastro) {
        await n.registrar(_nome.text.trim(), _email.text.trim(), _senha.text);
      } else {
        await n.login(_email.text.trim(), _senha.text);
      }
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _contasDeTeste() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Contas de teste', style: Theme.of(ctx).textTheme.titleMedium)),
          ),
          for (final e in const [
            ('Gestora Ambiental', 'gestor@ecoalerta.app', 'gestor123', 'Perfil de gestor'),
            ('Ana Souza', 'ana@ecoalerta.app', '123456', 'Cidadã'),
            ('Bruno Lima', 'bruno@ecoalerta.app', '123456', 'Cidadão'),
          ])
            ListTile(
              leading: CircleAvatar(backgroundColor: Theme.of(ctx).colorScheme.primaryContainer, child: Text(e.$1[0])),
              title: Text(e.$1),
              subtitle: Text('${e.$2}  ·  ${e.$4}'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _cadastro = false;
                  _email.text = e.$2;
                  _senha.text = e.$3;
                });
                _enviar();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final servidor = ref.watch(configProvider).servidorUrl;
    return Scaffold(
      backgroundColor: t.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: t.colorScheme.primary, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.eco_outlined, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('EcoAlerta', style: t.textTheme.titleLarge?.copyWith(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text('Registre e acompanhe problemas ambientais da sua cidade.', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  if (_cadastro) ...[
                    TextFormField(
                      controller: _nome,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Informe seu nome' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (v) => !(v ?? '').contains('@') ? 'Informe um e-mail válido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senha,
                    obscureText: !_verSenha,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      suffixIcon: IconButton(
                        icon: Icon(_verSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _verSenha = !_verSenha),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 6 ? 'A senha precisa ter pelo menos 6 caracteres' : null,
                    onFieldSubmitted: (_) => _enviar(),
                  ),
                  const SizedBox(height: 20),
                  BotaoPrimario(_cadastro ? 'Criar conta' : 'Entrar', onPressed: _enviar, carregando: _carregando),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _cadastro = !_cadastro),
                    child: Text(_cadastro ? 'Já tenho conta' : 'Criar uma conta'),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: t.colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _contasDeTeste,
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Usar uma conta de teste'),
                  ),
                  TextButton.icon(
                    onPressed: () => mostrarDialogoServidor(context, ref),
                    style: TextButton.styleFrom(foregroundColor: t.colorScheme.onSurfaceVariant, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
                    icon: const Icon(Icons.settings_ethernet, size: 16),
                    label: Text(servidor, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
