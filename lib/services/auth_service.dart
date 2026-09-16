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
}

class AuthService {
  static final _cliente = Supabase.instance.client;

  static User? get usuarioAtual => _cliente.auth.currentUser;
  static bool get estaLogado => usuarioAtual != null;

  static Future<void> entrar({
    required String email,
    required String senha,
  }) async {
    await _cliente.auth.signInWithPassword(email: email, password: senha);
  }

  static Future<void> sair() async {
    await _cliente.auth.signOut();
  }

  // Busca o perfil (nome e papel) do usuário logado
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

  // Território vinculado ao agente logado (null para coordenador)
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
}