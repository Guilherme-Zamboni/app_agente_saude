import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/morador.dart';
import 'database_helper.dart';

class MoradorDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Morador morador) async {
    final db = await dbHelper.database;
    await db.insert(
      'morador',
      morador.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Morador morador) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      morador.toMap(),
      where: 'id = ?',
      whereArgs: [morador.id],
    );
  }

  Future<void> inativar(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {'ativo': 0, 'atualizado_em': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Usado em cascata quando uma família inteira é excluída
  Future<void> inativarPorFamilia(String familiaId) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {'ativo': 0, 'atualizado_em': DateTime.now().toIso8601String()},
      where: 'familia_id = ?',
      whereArgs: [familiaId],
    );
  }

  Future<void> reativar(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'morador',
      {'ativo': 1, 'atualizado_em': DateTime.now().toIso8601String()},
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
    String? bairro,
  }) async {
    final db = await dbHelper.database;
    final condicoes = <String>['m.ativo = 1', 'f.ativo = 1', 'd.ativo = 1'];
    final valores = <dynamic>[];

    if (rua != null && rua.trim().isNotEmpty) {
      condicoes.add('d.rua LIKE ?');
      valores.add('%$rua%');
    }
    if (bairro != null && bairro.trim().isNotEmpty) {
      condicoes.add('d.bairro LIKE ?');
      valores.add('%$bairro%');
    }

    final resultado = await db.rawQuery('''
      SELECT m.* FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id
      INNER JOIN domicilio d ON f.domicilio_id = d.id
      WHERE ${condicoes.join(' AND ')}
    ''', valores);

    return resultado.map((m) => Morador.fromMap(m)).toList();
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

  Future<int> contarCriancasAte4Anos() async {
    final db = await dbHelper.database;
    final limite = DateTime.now().subtract(const Duration(days: 4 * 365));
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE data_nascimento >= ? AND ativo = 1',
      [limite.toIso8601String()],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<int> contarIdosos({int idadeMinima = 60}) async {
    final db = await dbHelper.database;
    final limite = DateTime.now().subtract(Duration(days: idadeMinima * 365));
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) as total FROM morador WHERE data_nascimento <= ? AND ativo = 1',
      [limite.toIso8601String()],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }
}