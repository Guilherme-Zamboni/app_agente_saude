import 'package:supabase_flutter/supabase_flutter.dart';

/// Consome a API de estatísticas exposta pelo servidor.
///
/// Endpoints (POST /rest/v1/rpc/<nome>):
///   estatisticas_territorio   { p_territorio_id }
///   estatisticas_consolidadas { }
///   estatisticas_visitas      { p_inicio, p_fim, p_territorio_id? }
///
/// As funções rodam com as permissões de quem chamou, então um agente
/// só recebe os dados da própria microárea mesmo chamando o consolidado.
class EstatisticasApiService {
  static final _cliente = Supabase.instance.client;

  static Future<Map<String, dynamic>> porTerritorio(String territorioId) async {
    final resposta = await _cliente.rpc(
      'estatisticas_territorio',
      params: {'p_territorio_id': territorioId},
    );
    return Map<String, dynamic>.from(resposta as Map);
  }

  static Future<Map<String, dynamic>> consolidadas() async {
    final resposta = await _cliente.rpc('estatisticas_consolidadas');
    return Map<String, dynamic>.from(resposta as Map);
  }

  static Future<Map<String, dynamic>> visitas({
    required DateTime inicio,
    required DateTime fim,
    String? territorioId,
  }) async {
    final resposta = await _cliente.rpc(
      'estatisticas_visitas',
      params: {
        'p_inicio': inicio.toIso8601String().split('T').first,
        'p_fim': fim.toIso8601String().split('T').first,
        if (territorioId != null) 'p_territorio_id': territorioId,
      },
    );
    return Map<String, dynamic>.from(resposta as Map);
  }
}