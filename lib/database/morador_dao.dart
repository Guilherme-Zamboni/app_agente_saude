import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/morador.dart';
import 'database_helper.dart';

class MoradorDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Morador morador) async {
    final db = await dbHelper.database;
    await db.insert(
      'morador',
      {...morador.toMap(), 'sincronizado': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Morador morador) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {...morador.toMap(), 'sincronizado': 0},
      where: 'id = ?',
      whereArgs: [morador.id],
    );
  }

  Future<void> inativar(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {
        'ativo': 0,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> inativarPorFamilia(String familiaId) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {
        'ativo': 0,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'familia_id = ?',
      whereArgs: [familiaId],
    );
  }

  Future<void> reativar(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {
        'ativo': 1,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Morador?> buscarPorId(String id) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'morador',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Morador.fromMap(resultado.first);
  }

  Future<String?> domicilioDoMorador(String moradorId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT d.id as domicilio_id
      FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id
      INNER JOIN domicilio d ON f.domicilio_id = d.id
      WHERE m.id = ?
    ''', [moradorId]);

    if (resultado.isEmpty) return null;
    return resultado.first['domicilio_id'] as String?;
  }

  Future<List<Morador>> listarPorFamilia(String familiaId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'morador',
      where: 'familia_id = ? AND ativo = 1',
      whereArgs: [familiaId],
    );
    return resultado.map((m) => Morador.fromMap(m)).toList();
  }

  Future<List<Morador>> listarPorTerritorio(String territorioId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT m.* FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id
      INNER JOIN domicilio d ON f.domicilio_id = d.id
      WHERE d.territorio_id = ? AND m.ativo = 1 AND f.ativo = 1 AND d.ativo = 1
    ''', [territorioId]);
    return resultado.map((m) => Morador.fromMap(m)).toList();
  }

  int _idade(DateTime nascimento) {
    final agora = DateTime.now();
    int idade = agora.year - nascimento.year;
    if (agora.month < nascimento.month ||
        (agora.month == nascimento.month && agora.day < nascimento.day)) {
      idade--;
    }
    return idade;
  }

  /// Marcadores de saúde de cada domicílio, usados nos filtros do mapa.
  Future<Map<String, Set<String>>> marcadoresPorDomicilio(
      String territorioId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT d.id as domicilio_id, m.comorbidades, m.gestante, m.acamado,
             m.data_nascimento
      FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id AND f.ativo = 1
      INNER JOIN domicilio d ON f.domicilio_id = d.id AND d.ativo = 1
      WHERE d.territorio_id = ? AND m.ativo = 1
    ''', [territorioId]);

    final mapa = <String, Set<String>>{};

    for (final linha in resultado) {
      final domicilioId = linha['domicilio_id'] as String;
      final marcadores = mapa.putIfAbsent(domicilioId, () => <String>{});

      final comorbidades = (linha['comorbidades'] as String?) ?? '';
      for (final c in comorbidades.split(',')) {
        if (c.trim().isNotEmpty) marcadores.add(c.trim());
      }

      if (linha['gestante'] == 1) marcadores.add('gestante');
      if (linha['acamado'] == 1) marcadores.add('acamado');

      final idade = _idade(DateTime.parse(linha['data_nascimento'] as String));
      if (idade < 2) marcadores.add('crianca');
      if (idade >= 60) marcadores.add('idoso');
    }

    return mapa;
  }

  String _normalizar(String texto) => texto.trim().toLowerCase();

  Future<bool> verificarDuplicidade({
    required String nome,
    required String nomeDaMae,
    required DateTime dataNascimento,
  }) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'morador',
      where:
          'LOWER(TRIM(nome)) = ? AND LOWER(TRIM(nome_da_mae)) = ? AND data_nascimento = ? AND ativo = 1',
      whereArgs: [
        _normalizar(nome),
        _normalizar(nomeDaMae),
        dataNascimento.toIso8601String(),
      ],
    );
    return resultado.isNotEmpty;
  }

  Future<List<Morador>> buscar({
    String? nome,
    String? nomeDaMae,
    DateTime? dataNascimento,
  }) async {
    final db = await dbHelper.database;
    final condicoes = <String>['ativo = 1'];
    final valores = <dynamic>[];

    if (nome != null && nome.trim().isNotEmpty) {
      condicoes.add('nome LIKE ?');
      valores.add('%$nome%');
    }
    if (nomeDaMae != null && nomeDaMae.trim().isNotEmpty) {
      condicoes.add('nome_da_mae LIKE ?');
      valores.add('%$nomeDaMae%');
    }
    if (dataNascimento != null) {
      condicoes.add('data_nascimento = ?');
      valores.add(dataNascimento.toIso8601String());
    }

    final resultado = await db.query(
      'morador',
      where: condicoes.join(' AND '),
      whereArgs: valores,
    );
    return resultado.map((m) => Morador.fromMap(m)).toList();
  }

  Future<List<Morador>> buscarPorEndereco({
    String? rua,
    String? numero,
  }) async {
    final db = await dbHelper.database;
    final condicoes = <String>['m.ativo = 1', 'f.ativo = 1', 'd.ativo = 1'];
    final valores = <dynamic>[];

    if (rua != null && rua.trim().isNotEmpty) {
      condicoes.add('d.rua LIKE ?');
      valores.add('%$rua%');
    }
    if (numero != null && numero.trim().isNotEmpty) {
      condicoes.add('d.numero LIKE ?');
      valores.add('%$numero%');
    }

    final resultado = await db.rawQuery('''
      SELECT m.* FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id
      INNER JOIN domicilio d ON f.domicilio_id = d.id
      WHERE ${condicoes.join(' AND ')}
    ''', valores);

    return resultado.map((m) => Morador.fromMap(m)).toList();
  }

  // ---------- ESTATÍSTICAS ----------

  /// Data exata de N anos atrás, no mesmo formato gravado no banco.
  String _dataHaAnos(int anos) {
    final hoje = DateTime.now();
    return DateTime(hoje.year - anos, hoje.month, hoje.day).toIso8601String();
  }

  Future<int> contarTotal() async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE ativo = 1',
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<int> contarPorComorbidade(String comorbidade) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE comorbidades LIKE ? AND ativo = 1',
      ['%$comorbidade%'],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<int> contarGestantes() async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE gestante = 1 AND ativo = 1',
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<int> contarAcamados() async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE acamado = 1 AND ativo = 1',
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  /// Crianças menores de 2 anos (quem completa 2 anos hoje já não conta).
  Future<int> contarCriancasMenores2Anos() async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE data_nascimento > ? AND ativo = 1',
      [_dataHaAnos(2)],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  /// Idosos com 60 anos ou mais.
  Future<int> contarIdosos({int idadeMinima = 60}) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE data_nascimento <= ? AND ativo = 1',
      [_dataHaAnos(idadeMinima)],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }
}