import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/domicilio.dart';
import '../models/familia.dart';
import '../models/morador.dart';

/// Consultas feitas diretamente no servidor, usadas pelo coordenador
/// (que não tem os dados das áreas no banco local).
class ConsultaService {
  static final _cliente = Supabase.instance.client;

  static Future<List<Domicilio>> domiciliosDoTerritorio(
      String territorioId) async {
    final resultado = await _cliente
        .from('domicilio')
        .select()
        .eq('territorio_id', territorioId)
        .eq('ativo', true);
    return resultado.map<Domicilio>((d) => Domicilio.fromMap(d)).toList();
  }

  static Future<List<Familia>> familiasDoDomicilio(String domicilioId) async {
    final resultado = await _cliente
        .from('familia')
        .select()
        .eq('domicilio_id', domicilioId)
        .eq('ativo', true);
    return resultado.map<Familia>((f) => Familia.fromMap(f)).toList();
  }

  static Future<List<Morador>> moradoresDaFamilia(String familiaId) async {
    final resultado = await _cliente
        .from('morador')
        .select()
        .eq('familia_id', familiaId)
        .eq('ativo', true);
    return resultado.map<Morador>((m) => Morador.fromMap(m)).toList();
  }

  /// Última visita de cada domicílio do território, para colorir os pinos.
  static Future<Map<String, DateTime>> ultimasVisitas(
      String territorioId) async {
    final domicilios = await _cliente
        .from('domicilio')
        .select('id')
        .eq('territorio_id', territorioId)
        .eq('ativo', true);

    final ids = domicilios.map<String>((d) => d['id'] as String).toList();
    if (ids.isEmpty) return {};

    final familias = await _cliente
        .from('familia')
        .select('id, domicilio_id')
        .inFilter('domicilio_id', ids)
        .eq('ativo', true);

    if (familias.isEmpty) return {};

    final mapaFamiliaDomicilio = <String, String>{};
    for (final f in familias) {
      mapaFamiliaDomicilio[f['id'] as String] = f['domicilio_id'] as String;
    }

    final visitas = await _cliente
        .from('visita')
        .select('familia_id, data_visita')
        .inFilter('familia_id', mapaFamiliaDomicilio.keys.toList())
        .eq('ativo', true);

    final resultado = <String, DateTime>{};
    for (final v in visitas) {
      final domicilioId = mapaFamiliaDomicilio[v['familia_id']];
      if (domicilioId == null) continue;
      final data = DateTime.parse(v['data_visita']);
      final atual = resultado[domicilioId];
      if (atual == null || data.isAfter(atual)) {
        resultado[domicilioId] = data;
      }
    }
    return resultado;
  }

  /// Marcadores de saúde por domicílio, para os filtros do mapa.
  static Future<Map<String, Set<String>>> marcadoresPorDomicilio(
      String territorioId) async {
    final domicilios = await _cliente
        .from('domicilio')
        .select('id')
        .eq('territorio_id', territorioId)
        .eq('ativo', true);

    final ids = domicilios.map<String>((d) => d['id'] as String).toList();
    if (ids.isEmpty) return {};

    final familias = await _cliente
        .from('familia')
        .select('id, domicilio_id')
        .inFilter('domicilio_id', ids)
        .eq('ativo', true);

    if (familias.isEmpty) return {};

    final mapaFamiliaDomicilio = <String, String>{};
    for (final f in familias) {
      mapaFamiliaDomicilio[f['id'] as String] = f['domicilio_id'] as String;
    }

    final moradores = await _cliente
        .from('morador')
        .select('familia_id, comorbidades, gestante, data_nascimento')
        .inFilter('familia_id', mapaFamiliaDomicilio.keys.toList())
        .eq('ativo', true);

    final agora = DateTime.now();
    final resultado = <String, Set<String>>{};

    for (final m in moradores) {
      final domicilioId = mapaFamiliaDomicilio[m['familia_id']];
      if (domicilioId == null) continue;

      final marcadores = resultado.putIfAbsent(domicilioId, () => <String>{});

      final comorbidades = (m['comorbidades'] as String?) ?? '';
      for (final c in comorbidades.split(',')) {
        if (c.trim().isNotEmpty) marcadores.add(c.trim());
      }

      if (m['gestante'] == true) marcadores.add('gestante');

      final nascimento = DateTime.parse(m['data_nascimento']);
      final idade = agora.year -
          nascimento.year -
          ((agora.month < nascimento.month ||
                  (agora.month == nascimento.month &&
                      agora.day < nascimento.day))
              ? 1
              : 0);
      if (idade <= 4) marcadores.add('crianca');
      if (idade >= 60) marcadores.add('idoso');
    }

    return resultado;
  }

  /// Busca de moradores dentro de um território específico.
  static Future<List<Morador>> buscarMoradores({
    required String territorioId,
    String? nome,
    String? nomeDaMae,
    DateTime? dataNascimento,
    String? rua,
    String? numero,
  }) async {
    var consultaDomicilios = _cliente
        .from('domicilio')
        .select('id')
        .eq('territorio_id', territorioId)
        .eq('ativo', true);

    if (rua != null && rua.trim().isNotEmpty) {
      consultaDomicilios = consultaDomicilios.ilike('rua', '%${rua.trim()}%');
    }
    if (numero != null && numero.trim().isNotEmpty) {
      consultaDomicilios =
          consultaDomicilios.ilike('numero', '%${numero.trim()}%');
    }

    final domicilios = await consultaDomicilios;
    final idsDomicilios =
        domicilios.map<String>((d) => d['id'] as String).toList();
    if (idsDomicilios.isEmpty) return [];

    final familias = await _cliente
        .from('familia')
        .select('id')
        .inFilter('domicilio_id', idsDomicilios)
        .eq('ativo', true);

    final idsFamilias = familias.map<String>((f) => f['id'] as String).toList();
    if (idsFamilias.isEmpty) return [];

    var consulta = _cliente
        .from('morador')
        .select()
        .inFilter('familia_id', idsFamilias)
        .eq('ativo', true);

    if (nome != null && nome.trim().isNotEmpty) {
      consulta = consulta.ilike('nome', '%${nome.trim()}%');
    }
    if (nomeDaMae != null && nomeDaMae.trim().isNotEmpty) {
      consulta = consulta.ilike('nome_da_mae', '%${nomeDaMae.trim()}%');
    }
    if (dataNascimento != null) {
      consulta = consulta.eq(
        'data_nascimento',
        dataNascimento.toIso8601String().split('T').first,
      );
    }

    final resultado = await consulta;
    return resultado.map<Morador>((m) => Morador.fromMap(m)).toList();
  }

  /// Ficha completa de um morador, incluindo o endereço onde mora.
  static Future<Map<String, dynamic>?> fichaCompleta(String moradorId) async {
    final resultado = await _cliente
        .from('morador')
        .select('*, familia:familia_id(*, domicilio:domicilio_id(*))')
        .eq('id', moradorId)
        .maybeSingle();
    return resultado;
  }

  /// Histórico de visitas de um morador: as gerais da família dele
  /// somadas às individuais dele mesmo.
  static Future<List<Map<String, dynamic>>> historicoVisitas({
    required String moradorId,
    required String familiaId,
  }) async {
    final resultado = await _cliente
        .from('visita')
        .select('*, registrado_por:perfil!visita_registrado_por_fkey(nome)')
        .or('morador_id.eq.$moradorId,and(familia_id.eq.$familiaId,morador_id.is.null)')
        .eq('ativo', true)
        .order('data_visita', ascending: false);
    return List<Map<String, dynamic>>.from(resultado);
  }

  /// Domicílio onde o morador reside (para localizar no mapa).
  static Future<String?> domicilioDoMorador(String moradorId) async {
    final resultado = await _cliente
        .from('morador')
        .select('familia:familia_id(domicilio_id)')
        .eq('id', moradorId)
        .maybeSingle();

    if (resultado == null) return null;
    final familia = resultado['familia'];
    return familia?['domicilio_id'] as String?;
  }
}