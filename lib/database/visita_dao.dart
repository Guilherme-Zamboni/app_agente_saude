import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/visita.dart';
import 'database_helper.dart';

class VisitaDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Visita visita) async {
    final db = await dbHelper.database;
    await db.insert(
      'visita',
      visita.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Visita visita) async {
    final db = await dbHelper.database;
    await db.update(
      'visita',
      visita.toMap(),
      where: 'id = ?',
      whereArgs: [visita.id],
    );
  }

  Future<void> deletar(String id) async {
    final db = await dbHelper.database;
    await db.delete(
      'visita',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Histórico de visitas GERAIS da família (morador_id nulo) - usado na
  // tela de detalhe do domicílio.
  Future<List<Visita>> listarGeraisPorFamilia(String familiaId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where: 'familia_id = ? AND morador_id IS NULL',
      whereArgs: [familiaId],
      orderBy: 'data_visita DESC',
    );
    return resultado.map((v) => Visita.fromMap(v)).toList();
  }

  // Histórico combinado de um morador específico: visitas gerais da família
  // dele + visitas extras individuais dele mesmo. Usado na ficha do morador.
  Future<List<Visita>> listarHistoricoDoMorador({
    required String moradorId,
    required String familiaId,
  }) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where: 'morador_id = ? OR (familia_id = ? AND morador_id IS NULL)',
      whereArgs: [moradorId, familiaId],
      orderBy: 'data_visita DESC',
    );
    return resultado.map((v) => Visita.fromMap(v)).toList();
  }

  Future<DateTime?> dataUltimaVisitaFamilia(String familiaId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where: 'familia_id = ? AND morador_id IS NULL',
      whereArgs: [familiaId],
      orderBy: 'data_visita DESC',
      limit: 1,
    );
    if (resultado.isEmpty) return null;
    return DateTime.parse(resultado.first['data_visita'] as String);
  }

  // Considera a visita mais recente entre a geral da família e as
  // individuais extras desse morador especificamente.
  Future<DateTime?> dataUltimaVisitaMorador({
    required String moradorId,
    required String familiaId,
  }) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT MAX(data_visita) as ultima FROM visita
      WHERE morador_id = ? OR (familia_id = ? AND morador_id IS NULL)
    ''', [moradorId, familiaId]);

    final ultima = resultado.first['ultima'] as String?;
    if (ultima == null) return null;
    return DateTime.parse(ultima);
  }

  Future<int?> diasDesdeUltimaVisitaMorador({
    required String moradorId,
    required String familiaId,
  }) async {
    final ultima = await dataUltimaVisitaMorador(moradorId: moradorId, familiaId: familiaId);
    if (ultima == null) return null;
    return DateTime.now().difference(ultima).inDays;
  }

  Future<List<String>> moradoresPendentesDeVisita({
    required String territorioId,
    int diasLimite = 30,
  }) async {
    final db = await dbHelper.database;
    final limite = DateTime.now().subtract(Duration(days: diasLimite));

    final resultado = await db.rawQuery('''
      SELECT m.id,
        MAX(
          CASE WHEN v.morador_id = m.id THEN v.data_visita
               WHEN v.familia_id = f.id AND v.morador_id IS NULL THEN v.data_visita
               ELSE NULL END
        ) as ultima_visita
      FROM morador m
      INNER JOIN familia f ON m.familia_id = f.id
      INNER JOIN domicilio d ON f.domicilio_id = d.id
      LEFT JOIN visita v ON v.morador_id = m.id OR (v.familia_id = f.id AND v.morador_id IS NULL)
      WHERE d.territorio_id = ? AND m.ativo = 1
      GROUP BY m.id
      HAVING ultima_visita IS NULL OR ultima_visita < ?
    ''', [territorioId, limite.toIso8601String()]);

    return resultado.map((r) => r['id'] as String).toList();
  }

    // Data da visita mais recente de um domicílio (considerando todas as
  // famílias dele, e tanto visitas gerais quanto individuais)
  Future<DateTime?> dataUltimaVisitaDomicilio(String domicilioId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT MAX(v.data_visita) as ultima
      FROM visita v
      INNER JOIN familia f ON v.familia_id = f.id
      WHERE f.domicilio_id = ? AND f.ativo = 1
    ''', [domicilioId]);

    final ultima = resultado.first['ultima'] as String?;
    if (ultima == null) return null;
    return DateTime.parse(ultima);
  }

  // Mapa com a última visita de cada domicílio de um território,
  // para colorir os pinos do mapa de uma vez só (sem uma consulta por casa)
  Future<Map<String, DateTime>> ultimasVisitasPorTerritorio(
      String territorioId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT d.id as domicilio_id, MAX(v.data_visita) as ultima
      FROM domicilio d
      INNER JOIN familia f ON f.domicilio_id = d.id AND f.ativo = 1
      INNER JOIN visita v ON v.familia_id = f.id
      WHERE d.territorio_id = ? AND d.ativo = 1
      GROUP BY d.id
    ''', [territorioId]);

    final mapa = <String, DateTime>{};
    for (final linha in resultado) {
      final ultima = linha['ultima'] as String?;
      if (ultima != null) {
        mapa[linha['domicilio_id'] as String] = DateTime.parse(ultima);
      }
    }
    return mapa;
  }
  
}