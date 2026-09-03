import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/territorio.dart';
import 'database_helper.dart';

class TerritorioDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Territorio territorio) async {
    final db = await dbHelper.database;
    await db.insert(
      'territorio',
      territorio.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Territorio territorio) async {
    final db = await dbHelper.database;
    await db.update(
      'territorio',
      territorio.toMap(),
      where: 'id = ?',
      whereArgs: [territorio.id],
    );
  }

  Future<Territorio?> buscarPorId(String id) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'territorio',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Territorio.fromMap(resultado.first);
  }

  // Lista os territórios de um agente específico (útil se um agente
  // puder ter mais de uma microárea, ou pra tela de seleção no login)
  Future<List<Territorio>> listarPorAgente(String agenteId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'territorio',
      where: 'agente_id = ?',
      whereArgs: [agenteId],
    );
    return resultado.map((t) => Territorio.fromMap(t)).toList();
  }
}