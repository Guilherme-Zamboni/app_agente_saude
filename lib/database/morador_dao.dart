import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/morador.dart';
import '../utils/texto.dart';
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

  /// Verifica se já existe morador com o mesmo nome, nome da mãe e
  /// nascimento. Ignora maiúsculas e acentos.
  Future<bool> verificarDuplicidade({
    required String nome,
    required String nomeDaMae,
    required DateTime dataNascimento,
  }) async {
    final db = await dbHelper.database;

    // compara a data pelos 10 primeiros caracteres (AAAA-MM-DD)
    final dia = dataNascimento.toIso8601String().substring(0, 10);

    final candidatos = await db.query(
      'morador',
      columns: ['nome', 'nome_da_mae'],
      where: 'ativo = 1 AND substr(data_nascimento, 1, 10) = ?',
      whereArgs: [dia],
    );

    final n = normalizar(nome);
    final m = normalizar(nomeDaMae);

    return candidatos.any((c) =>
        normalizar(c['nome'] as String) == n &&
        normalizar(c['nome_da_mae'] as String) == m);
  }

  /// Busca por qualquer combinação de nome, mãe, nascimento, rua e número.
  /// Ignora maiúsculas e acentos.
  Future<List<Morador>> buscar({
    String? nome,
    String? nomeDaMae,
    DateTime? dataNascimento,
    String? rua,
    String? numero,
  }) async {
    final db = await dbHelper.database;

    final linhas = await db.rawQuery('''
      SELECT m.*, d.rua AS dom_rua, d.numero AS dom_numero
      FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id AND f.ativo = 1
      INNER JOIN domicilio d ON f.domicilio_id = d.id AND d.ativo = 1
      WHERE m.ativo = 1
    ''');

    final qNome = normalizar(nome ?? '');
    final qMae = normalizar(nomeDaMae ?? '');
    final qRua = normalizar(rua ?? '');
    final qNumero = normalizar(numero ?? '');

    bool contem(Object? campo, String busca) =>
        busca.isEmpty || normalizar((campo as String?) ?? '').contains(busca);

    final resultado = linhas.where((l) {
      if (!contem(l['nome'], qNome)) return false;
      if (!contem(l['nome_da_mae'], qMae)) return false;
      if (!contem(l['dom_rua'], qRua)) return false;
      if (!contem(l['dom_numero'], qNumero)) return false;

      if (dataNascimento != null) {
        final nasc = DateTime.parse(l['data_nascimento'] as String);
        if (nasc.year != dataNascimento.year ||
            nasc.month != dataNascimento.month ||
            nasc.day != dataNascimento.day) {
          return false;
        }
      }
      return true;
    }).map((l) => Morador.fromMap(l)).toList();

    resultado.sort((a, b) => normalizar(a.nome).compareTo(normalizar(b.nome)));
    return resultado;
  }

  Future<List<Morador>> buscarPorEndereco({
    String? rua,
    String? numero,
  }) =>
      buscar(rua: rua, numero: numero);

  // ---------- ESTATÍSTICAS ----------
  //
  // Todas as contagens consideram apenas moradores ativos, de famílias
  // ativas, em domicílios ativos. Quando [territorioId] é informado, contam
  // somente a microárea indicada; sem ele, contam tudo o que está gravado
  // no aparelho.

  /// Data exata de N anos atrás, no mesmo formato gravado no banco.
  String _dataHaAnos(int anos) {
    final hoje = DateTime.now();
    return DateTime(hoje.year - anos, hoje.month, hoje.day).toIso8601String();
  }

  Future<int> _contar({
    String condicao = '',
    List<Object?> argumentos = const [],
    String? territorioId,
  }) async {
    final db = await dbHelper.database;

    final filtros = <String>['m.ativo = 1'];
    final valores = <Object?>[];

    if (territorioId != null) {
      filtros.add('d.territorio_id = ?');
      valores.add(territorioId);
    }
    if (condicao.isNotEmpty) {
      filtros.add(condicao);
      valores.addAll(argumentos);
    }

    final resultado = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM morador m
      INNER JOIN familia f ON f.id = m.familia_id AND f.ativo = 1
      INNER JOIN domicilio d ON d.id = f.domicilio_id AND d.ativo = 1
      WHERE ${filtros.join(' AND ')}
    ''', valores);

    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<int> contarTotal({String? territorioId}) =>
      _contar(territorioId: territorioId);

  Future<int> contarPorComorbidade(String comorbidade,
          {String? territorioId}) =>
      _contar(
        condicao: 'm.comorbidades LIKE ?',
        argumentos: ['%$comorbidade%'],
        territorioId: territorioId,
      );

  Future<int> contarGestantes({String? territorioId}) =>
      _contar(condicao: 'm.gestante = 1', territorioId: territorioId);

  Future<int> contarAcamados({String? territorioId}) =>
      _contar(condicao: 'm.acamado = 1', territorioId: territorioId);

  /// Crianças menores de 2 anos (quem completa 2 anos hoje já não conta).
  Future<int> contarCriancasMenores2Anos({String? territorioId}) => _contar(
        condicao: 'm.data_nascimento > ?',
        argumentos: [_dataHaAnos(2)],
        territorioId: territorioId,
      );

  /// Idosos com 60 anos ou mais.
  Future<int> contarIdosos({int idadeMinima = 60, String? territorioId}) =>
      _contar(
        condicao: 'm.data_nascimento <= ?',
        argumentos: [_dataHaAnos(idadeMinima)],
        territorioId: territorioId,
      );
}