import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/domicilio.dart';
import 'database_helper.dart';
import 'familia_dao.dart';

/// Rua e bairro já usados na microárea, para sugerir no cadastro.
class SugestaoEndereco {
  final String rua;
  final String bairro;
  final int total;

  SugestaoEndereco(this.rua, this.bairro, this.total);
}

class DomicilioDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Domicilio domicilio) async {
    final db = await dbHelper.database;
    await db.insert(
      'domicilio',
      {...domicilio.toMap(), 'sincronizado': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Domicilio domicilio) async {
    final db = await dbHelper.database;
    final dados = domicilio.toMap()..remove('criado_em');
    await db.update(
      'domicilio',
      {
        ...dados,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [domicilio.id],
    );
  }

  Future<void> atualizarPosicao(String id, double posX, double posY) async {
    final db = await dbHelper.database;
    await db.update(
      'domicilio',
      {
        'pos_x': posX,
        'pos_y': posY,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> inativar(String id) async {
    final db = await dbHelper.database;

    await db.update(
      'domicilio',
      {
        'ativo': 0,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final familias = await db.query(
      'familia',
      where: 'domicilio_id = ? AND ativo = 1',
      whereArgs: [id],
    );

    final familiaDao = FamiliaDao();
    for (final f in familias) {
      await familiaDao.inativar(f['id'] as String);
    }
  }

  Future<Domicilio?> buscarPorId(String id) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'domicilio',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Domicilio.fromMap(resultado.first);
  }

  Future<List<Domicilio>> listarPorTerritorio(String territorioId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'domicilio',
      where: 'territorio_id = ? AND ativo = 1',
      whereArgs: [territorioId],
    );
    return resultado.map((d) => Domicilio.fromMap(d)).toList();
  }

  /// Domicílios ativos sem nenhuma família ativa (casas não cadastradas).
  Future<Set<String>> idsNaoCadastrados(String territorioId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT d.id FROM domicilio d
      WHERE d.territorio_id = ? AND d.ativo = 1
        AND NOT EXISTS (
          SELECT 1 FROM familia f WHERE f.domicilio_id = d.id AND f.ativo = 1
        )
    ''', [territorioId]);
    return resultado.map((r) => r['id'] as String).toSet();
  }

  /// Combinações de rua e bairro já cadastradas, das mais usadas
  /// para as menos usadas.
  Future<List<SugestaoEndereco>> sugestoesDeEndereco(
      String territorioId) async {
    final db = await dbHelper.database;
    final linhas = await db.rawQuery('''
      SELECT rua, bairro, COUNT(*) AS total
      FROM domicilio
      WHERE territorio_id = ? AND ativo = 1 AND TRIM(rua) <> ''
      GROUP BY rua, bairro
      ORDER BY total DESC
    ''', [territorioId]);

    return linhas
        .map((l) => SugestaoEndereco(
              l['rua'] as String,
              (l['bairro'] as String?) ?? '',
              (l['total'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<List<Domicilio>> buscarPorEndereco({
    String? rua,
    String? numero,
  }) async {
    final db = await dbHelper.database;
    final condicoes = <String>['ativo = 1'];
    final valores = <dynamic>[];

    if (rua != null && rua.trim().isNotEmpty) {
      condicoes.add('rua LIKE ?');
      valores.add('%$rua%');
    }
    if (numero != null && numero.trim().isNotEmpty) {
      condicoes.add('numero LIKE ?');
      valores.add('%$numero%');
    }

    final resultado = await db.query(
      'domicilio',
      where: condicoes.join(' AND '),
      whereArgs: valores,
    );
    return resultado.map((d) => Domicilio.fromMap(d)).toList();
  }
}