import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/domicilio.dart';
import 'database_helper.dart';
import 'familia_dao.dart';

class DomicilioDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Domicilio domicilio) async {
    final db = await dbHelper.database;
    await db.insert(
      'domicilio',
      domicilio.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Domicilio domicilio) async {
    final db = await dbHelper.database;
    await db.update(
      'domicilio',
      domicilio.toMap(),
      where: 'id = ?',
      whereArgs: [domicilio.id],
    );
  }

    // Salva a posição do pino no mapa (coordenadas relativas, 0.0 a 1.0)
  Future<void> atualizarPosicao(String id, double posX, double posY) async {
    final db = await dbHelper.database;
    await db.update(
      'domicilio',
      {'pos_x': posX, 'pos_y': posY},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Inativação em cascata: domicílio -> famílias -> moradores
  Future<void> inativar(String id) async {
    final db = await dbHelper.database;

    await db.update(
      'domicilio',
      {'ativo': 0},
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

  Future<List<Domicilio>> buscarPorEndereco({
    String? rua,
    String? bairro,
  }) async {
    final db = await dbHelper.database;
    final condicoes = <String>['ativo = 1'];
    final valores = <dynamic>[];

    if (rua != null && rua.trim().isNotEmpty) {
      condicoes.add('rua LIKE ?');
      valores.add('%$rua%');
    }
    if (bairro != null && bairro.trim().isNotEmpty) {
      condicoes.add('bairro LIKE ?');
      valores.add('%$bairro%');
    }

    final resultado = await db.query(
      'domicilio',
      where: condicoes.join(' AND '),
      whereArgs: valores,
    );
    return resultado.map((d) => Domicilio.fromMap(d)).toList();
  }
}