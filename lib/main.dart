import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/territorio.dart';
import 'database/territorio_dao.dart';
import 'screens/tela_mapa_territorio.dart';
import 'screens/tela_bloqueio.dart';

const String territorioTesteId = 'territorio-teste-001';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F7F5),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
        ),
      ),
      home: const TelaInicial(),
    );
  }
}

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final _territorioDao = TerritorioDao();
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _prepararTerritorioTeste();
  }

  Future<void> _prepararTerritorioTeste() async {
    final existente = await _territorioDao.buscarPorId(territorioTesteId);

    if (existente == null) {
      await _territorioDao.inserir(
        Territorio(
          id: territorioTesteId,
          nome: 'Território de Teste',
          agenteId: 'agente-teste-001',
        ),
      );
    }

    setState(() => _pronto = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return TelaBloqueio(
      telaAposDesbloqueio: const TelaMapaTerritorio(
        territorioId: territorioTesteId,
        nomeTerritorio: 'Território de Teste',
      ),
    );
  }
}