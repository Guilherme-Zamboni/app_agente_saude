import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  static final _cliente = Supabase.instance.client;

  // --- AGENTES ---

  static Future<List<Map<String, dynamic>>> listarAgentes() async {
    final resultado = await _cliente
        .from('perfil')
        .select('*, territorio:territorio!territorio_agente_id_fkey(id, nome)')
        .eq('papel', 'agente')
        .order('nome');
    return List<Map<String, dynamic>>.from(resultado);
  }

  static Future<void> criarAgente({
    required String email,
    required String senha,
    required String nome,
  }) async {
    final resposta = await _cliente.functions.invoke(
      'criar-agente',
      body: {'email': email, 'senha': senha, 'nome': nome, 'papel': 'agente'},
    );

    if (resposta.status != 200) {
      final dados = resposta.data;
      throw Exception(dados is Map ? dados['erro'] : 'Erro ao criar agente');
    }
  }

  static Future<void> atualizarAgente({
    required String id,
    required String nome,
    required bool ativo,
  }) async {
    await _cliente
        .from('perfil')
        .update({'nome': nome, 'ativo': ativo}).eq('id', id);
  }

  // --- TERRITÓRIOS ---

  static Future<List<Map<String, dynamic>>> listarTerritorios() async {
    final resultado = await _cliente
        .from('territorio')
        .select('*, agente:perfil!territorio_agente_id_fkey(id, nome)')
        .eq('ativo', true)
        .order('nome');
    return List<Map<String, dynamic>>.from(resultado);
  }

  static Future<void> criarTerritorio({
    required String nome,
    String? agenteId,
  }) async {
    await _cliente.from('territorio').insert({
      'nome': nome,
      'agente_id': agenteId,
    });
  }

  static Future<void> atualizarTerritorio({
    required String id,
    required String nome,
    String? agenteId,
  }) async {
    await _cliente.from('territorio').update({
      'nome': nome,
      'agente_id': agenteId,
    }).eq('id', id);
  }

  static Future<void> inativarTerritorio(String id) async {
    await _cliente.from('territorio').update({'ativo': false}).eq('id', id);
  }
}