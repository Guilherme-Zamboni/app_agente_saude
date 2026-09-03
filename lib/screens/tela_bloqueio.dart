import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class TelaBloqueio extends StatefulWidget {
  final Widget telaAposDesbloqueio;

  const TelaBloqueio({super.key, required this.telaAposDesbloqueio});

  @override
  State<TelaBloqueio> createState() => _TelaBloqueioState();
}

class _TelaBloqueioState extends State<TelaBloqueio> {
  final _auth = LocalAuthentication();
  bool _autenticado = false;
  bool _autenticando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _autenticar();
  }

  Future<void> _autenticar() async {
    setState(() {
      _autenticando = true;
      _erro = null;
    });

    try {
      final suportado = await _auth.isDeviceSupported();

      if (!suportado) {
        // Aparelho sem biometria/PIN configurado - libera o acesso
        // (evita travar o app em testes em emulador sem tela de bloqueio)
        setState(() {
          _autenticado = true;
          _autenticando = false;
        });
        return;
      }

      final autenticado = await _auth.authenticate(
        localizedReason: 'Autentique-se para acessar os dados dos moradores',
        biometricOnly: false, // permite PIN/senha do aparelho como alternativa
      );

      setState(() {
        _autenticado = autenticado;
        _autenticando = false;
        if (!autenticado) _erro = 'Autenticação não realizada';
      });
    } catch (e) {
      setState(() {
        _autenticando = false;
        _erro = 'Não foi possível autenticar neste aparelho';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_autenticado) {
      return widget.telaAposDesbloqueio;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.teal),
              const SizedBox(height: 24),
              const Text(
                'Aplicativo protegido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use sua digital, rosto ou PIN do celular para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 16),
                Text(_erro!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 32),
              if (_autenticando)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _autenticar,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Tentar novamente'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}