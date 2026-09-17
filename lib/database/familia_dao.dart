import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/familia.dart';
import 'database_helper.dart';
import 'morador_dao.dart';

class FamiliaDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Familia familia) async {
    final db = await dbHelper.database;
    await db.insert(
      'familia',
      {...familia.toMap(), 'sincronizado': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Familia familia) async {
    final db = await dbHelper.database;
    await db.update(
      'familia',
      {
        ...familia.toMap(),
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [familia.id],
    );
  }

  Future<void> inativar(String id) async {
    final db = await dbHelper.database;

    await db.update(
      'familia',
      {
        'ativo': 0,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final moradorDao = MoradorDao();
    await moradorDao.inativarPorFamilia(id);
  }

  Future<Familia?> buscarPorId(String id) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'familia',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Familia.fromMap(resultado.first);
  }

  Future<List<Familia>> listarPorDomicilio(String domicilioId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'familia',
      where: 'domicilio_id = ? AND ativo = 1',
      whereArgs: [domicilioId],
    );
    return resultado.map((f) => Familia.fromMap(f)).toList();
  }
}