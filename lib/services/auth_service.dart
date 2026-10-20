import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilUsuario {
  final String id;
  final String nome;
  final String papel; // 'agente' ou 'coordenador'

  PerfilUsuario({required this.id, required this.nome, required this.papel});

  bool get eCoordenador => papel == 'coordenador';
  bool get eAgente => papel == 'agente';

  factory PerfilUsuario.fromMap(Map<String, dynamic> map) {
    return PerfilUsuario(
      id: map['id'],
      nome: map['nome'],
      papel: map['papel'],
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'papel': papel};
}

/// Resultado do carregamento da sessão ao abrir o app.
class SessaoCarregada {
  final PerfilUsuario? perfil;
  final Map<String, dynamic>? territorio;

  /// true quando o servidor não respondeu e foram usados os dados
  /// guardados no aparelho.
  final bool offline;

  SessaoCarregada({this.perfil, this.territorio, this.offline = false});
}

class AuthService {
  static final _cliente = Supabase.instance.client;
  static const _armazenamento = FlutterSecureStorage();
  static const _prefixoCache = 'sessao_';

  // com cópia guardada, não vale esperar muito pelo servidor
  static const _limiteComCache = Duration(seconds: 8);
  static const _limiteSemCache = Duration(seconds: 20);

  static User? get usuarioAtual => _cliente.auth.currentUser;
  static bool get estaLogado => usuarioAtual != null;

  static Future<void> entrar({
    required String email,
    required String senha,
  }) async {
    await _cliente.auth.signInWithPassword(email: email, password: senha);
  }

  static Future<void> sair() async {
    // apaga a cópia guardada: o próximo login precisa ser feito com internet
    final id = usuarioAtual?.id;
    if (id != null) await _limparCache(id);
    await _cliente.auth.signOut();
  }

  // ---------- consultas ao servidor ----------

  /// Busca o perfil (nome e papel) do usuário logado.
  static Future<PerfilUsuario?> carregarPerfil() async {
    final usuario = usuarioAtual;
    if (usuario == null) return null;

    final resultado = await _cliente
        .from('perfil')
        .select()
        .eq('id', usuario.id)
        .maybeSingle();

    if (resultado == null) return null;
    return PerfilUsuario.fromMap(resultado);
  }

  /// Território vinculado ao agente logado (null para coordenador).
  static Future<Map<String, dynamic>?> meuTerritorio() async {
    final usuario = usuarioAtual;
    if (usuario == null) return null;

    final resultado = await _cliente
        .from('territorio')
        .select()
        .eq('agente_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    return resultado;
  }

  // ---------- sessão com cópia local ----------

  /// Carrega perfil e território. Se o servidor não responder e houver uma
  /// cópia guardada de um agente, usa a cópia para o app abrir mesmo sem
  /// internet.
  static Future<SessaoCarregada> carregarSessao() async {
    final usuario = usuarioAtual;
    if (usuario == null) return SessaoCarregada();

    final guardada = await _lerCache(usuario.id);
    final limite = guardada != null ? _limiteComCache : _limiteSemCache;

    try {
      final perfil = await carregarPerfil().timeout(limite);
      final territorio = await meuTerritorio().timeout(limite);

      // só guarda quando o servidor confirmou o perfil
      if (perfil != null) {
        await _salvarCache(usuario.id, perfil, territorio);
      }

      return SessaoCarregada(perfil: perfil, territorio: territorio);
    } catch (e) {
      debugPrint('>>> Servidor indisponível ao abrir ($e)');

      // a cópia só vale para agente: o painel do coordenador depende
      // do servidor em todas as telas
      if (guardada != null &&
          guardada.perfil != null &&
          guardada.perfil!.eAgente &&
          guardada.territorio != null) {
        return SessaoCarregada(
          perfil: guardada.perfil,
          territorio: guardada.territorio,
          offline: true,
        );
      }

      rethrow;
    }
  }

  // ---------- cópia guardada no aparelho ----------

  static String _chave(String usuarioId) => '$_prefixoCache$usuarioId';

  static Future<void> _salvarCache(
    String usuarioId,
    PerfilUsuario perfil,
    Map<String, dynamic>? territorio,
  ) async {
    try {
      await _armazenamento.write(
        key: _chave(usuarioId),
        value: jsonEncode({
          'perfil': perfil.toMap(),
          'territorio': territorio,
        }),
      );
    } catch (e) {
      debugPrint('>>> Não foi possível guardar a sessão: $e');
    }
  }

  static Future<SessaoCarregada?> _lerCache(String usuarioId) async {
    try {
      final texto = await _armazenamento.read(key: _chave(usuarioId));
      if (texto == null) return null;

      final dados = jsonDecode(texto) as Map<String, dynamic>;
      final perfilMap = dados['perfil'] as Map<String, dynamic>?;
      final territorioMap = dados['territorio'] as Map<String, dynamic>?;

      return SessaoCarregada(
        perfil: perfilMap == null ? null : PerfilUsuario.fromMap(perfilMap),
        territorio: territorioMap,
      );
    } catch (e) {
      debugPrint('>>> Cópia da sessão ilegível, ignorando: $e');
      return null;
    }
  }

  static Future<void> _limparCache(String usuarioId) async {
    try {
      await _armazenamento.delete(key: _chave(usuarioId));
    } catch (_) {}
  }
}