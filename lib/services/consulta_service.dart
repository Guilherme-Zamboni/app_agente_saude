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

  /// Visita mais recente de cada domicílio, com o resultado.
  static Future<Map<String, Map<String, dynamic>>> ultimaVisitaPorDomicilio(
      String territorioId) async {
    final domicilios = await _cliente
        .from('domicilio')
        .select('id')
        .eq('territorio_id', territorioId)
        .eq('ativo', true);

    final ids = domicilios.map<String>((d) => d['id'] as String).toList();
    if (ids.isEmpty) return {};

    final visitas = await _cliente
        .from('visita')
        .select('domicilio_id, data_visita, resultado')
        .inFilter('domicilio_id', ids)
        .eq('ativo', true)
        .order('data_visita', ascending: false);

    final resultado = <String, Map<String, dynamic>>{};
    for (final v in visitas) {
      resultado.putIfAbsent(
          v['domicilio_id'] as String, () => Map<String, dynamic>.from(v));
    }
    return resultado;
  }

  /// Domicílios sem nenhuma família ativa (casas não cadastradas).
  static Future<Set<String>> idsNaoCadastrados(String territorioId) async {
    final domicilios = await _cliente
        .from('domicilio')
        .select('id')
        .eq('territorio_id', territorioId)
        .eq('ativo', true);

    final ids = domicilios.map<String>((d) => d['id'] as String).toSet();
    if (ids.isEmpty) return {};

    final familias = await _cliente
        .from('familia')
        .select('domicilio_id')
        .inFilter('domicilio_id', ids.toList())
        .eq('ativo', true);

    final comFamilia =
        familias.map<String>((f) => f['domicilio_id'] as String).toSet();

    return ids.difference(comFamilia);
  }

  /// Tentativas de visita registradas em uma casa sem família.
  static Future<List<Map<String, dynamic>>> tentativasDoDomicilio(
      String domicilioId) async {
    final resultado = await _cliente
        .from('visita')
        .select('*, registrado_por:perfil!visita_registrado_por_fkey(nome)')
        .eq('domicilio_id', domicilioId)
        .isFilter('familia_id', null)
        .eq('ativo', true)
        .order('data_visita', ascending: false);
    return List<Map<String, dynamic>>.from(resultado);
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
        .select('familia_id, comorbidades, gestante, acamado, data_nascimento')
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
      if (m['acamado'] == true) marcadores.add('acamado');

      final nascimento = DateTime.parse(m['data_nascimento']);
      int idade = agora.year - nascimento.year;
      if (agora.month < nascimento.month ||
          (agora.month == nascimento.month && agora.day < nascimento.day)) {
        idade--;
      }
      if (idade < 2) marcadores.add('crianca');
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