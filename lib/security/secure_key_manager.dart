import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyManager {
  static const _storage = FlutterSecureStorage();
  static const _chaveArmazenamento = 'chave_banco_dados';

  // Retorna a chave de criptografia do banco. Se ainda não existir
  // (primeira vez que o app abre), gera uma nova e guarda com segurança
  // no armazenamento seguro do sistema (Keystore no Android).
  static Future<String> obterOuCriarChave() async {
    final chaveExistente = await _storage.read(key: _chaveArmazenamento);
    if (chaveExistente != null) return chaveExistente;

    final novaChave = _gerarChaveAleatoria();
    await _storage.write(key: _chaveArmazenamento, value: novaChave);
    return novaChave;
  }

  static String _gerarChaveAleatoria({int tamanhoBytes = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(tamanhoBytes, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}