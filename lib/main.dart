import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/tela_login.dart';
import 'screens/tela_mapa_territorio.dart';
import 'screens/tela_painel_coordenador.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Agente de Saúde',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F7F5),
        textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 18)),
      ),
      home: const Roteador(),
    );
  }
}

class Roteador extends StatefulWidget {
  const Roteador({super.key});

  @override
  State<Roteador> createState() => _RoteadorState();
}

class _RoteadorState extends State<Roteador> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final sessao = Supabase.instance.client.auth.currentSession;

        if (sessao == null) {
          return const TelaLogin();
        }

        return const _CarregandoPerfil();
      },
    );
  }
}

class _CarregandoPerfil extends StatefulWidget {
  const _CarregandoPerfil();

  @override
  State<_CarregandoPerfil> createState() => _CarregandoPerfilState();
}

class _CarregandoPerfilState extends State<_CarregandoPerfil> {
  late Future<SessaoCarregada> _future;
  bool _avisouOffline = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<SessaoCarregada> _carregar() async {
    final sessao = await AuthService.carregarSessao();

    // grava o território no banco local para as chaves estrangeiras funcionarem
    if (sessao.territorio != null) {
      await SyncService.garantirTerritorioLocal(sessao.territorio!);
    }

    return sessao;
  }

  void _tentarNovamente() {
    setState(() => _future = _carregar());
  }

  void _avisarModoOffline() {
    if (_avisouOffline) return;
    _avisouOffline = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sem conexão com o servidor. Usando os dados salvos no aparelho; '
            'o que você registrar será enviado quando a internet voltar.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessaoCarregada>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('>>> ERRO AO CARREGAR SESSÃO: ${snapshot.error}');
          return _telaErro(snapshot.error!);
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final sessao = snapshot.data!;
        final perfil = sessao.perfil;
        final territorio = sessao.territorio;

        if (perfil == null) {
          return _telaAviso(
            'Seu usuário ainda não tem perfil cadastrado. '
            'Fale com a coordenação.',
          );
        }

        if (perfil.eCoordenador) {
          return TelaPainelCoordenador(perfil: perfil);
        }

        if (territorio == null) {
          return _telaAviso(
            'Olá, ${perfil.nome}!\n\n'
            'Você ainda não tem uma microárea vinculada. '
            'Fale com a coordenação.',
          );
        }

        if (sessao.offline) _avisarModoOffline();

        return TelaMapaTerritorio(
          territorioId: territorio['id'],
          nomeTerritorio: territorio['nome'],
          imagemMapa: territorio['imagem_mapa'] as String?,
          proporcaoMapa: (territorio['proporcao_mapa'] as num?)?.toDouble(),
        );
      },
    );
  }

  Widget _telaErro(Object erro) {
    final demorou = erro is TimeoutException;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.black38),
              const SizedBox(height: 16),
              Text(
                demorou
                    ? 'O servidor demorou demais para responder.\n'
                        'Verifique a internet e tente novamente.'
                    : 'Não foi possível carregar seus dados.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              if (!demorou) ...[
                const SizedBox(height: 12),
                Text(
                  '$erro',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _tentarNovamente,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => AuthService.sair(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telaAviso(String mensagem) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 56, color: Colors.black38),
              const SizedBox(height: 16),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => AuthService.sair(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}