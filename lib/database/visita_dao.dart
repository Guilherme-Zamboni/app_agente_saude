import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/visita.dart';
import 'database_helper.dart';

class VisitaDao {
  final dbHelper = DatabaseHelper.instance;

  Future<void> inserir(Visita visita) async {
    final db = await dbHelper.database;
    await db.insert(
      'visita',
      {...visita.toMap(), 'sincronizado': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizar(Visita visita) async {
    final db = await dbHelper.database;
    await db.update(
      'visita',
      {
        ...visita.toMap(),
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [visita.id],
    );
  }

  /// Exclusão lógica, para que o servidor também seja informado.
  Future<void> inativar(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'visita',
      {
        'ativo': 0,
        'atualizado_em': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Visitas gerais de uma família (sem morador específico).
  Future<List<Visita>> listarGeraisPorFamilia(String familiaId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where: 'familia_id = ? AND morador_id IS NULL AND ativo = 1',
      whereArgs: [familiaId],
      orderBy: 'data_visita DESC',
    );
    return resultado.map((v) => Visita.fromMap(v)).toList();
  }

  /// Tentativas registradas em um domicílio sem família cadastrada.
  Future<List<Visita>> listarTentativasDoDomicilio(String domicilioId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where: 'domicilio_id = ? AND familia_id IS NULL AND ativo = 1',
      whereArgs: [domicilioId],
      orderBy: 'data_visita DESC',
    );
    return resultado.map((v) => Visita.fromMap(v)).toList();
  }

  /// Histórico de um morador: visitas gerais da família + individuais dele.
  Future<List<Visita>> listarHistoricoDoMorador({
    required String moradorId,
    required String familiaId,
  }) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where:
          '(morador_id = ? OR (familia_id = ? AND morador_id IS NULL)) AND ativo = 1',
      whereArgs: [moradorId, familiaId],
      orderBy: 'data_visita DESC',
    );
    return resultado.map((v) => Visita.fromMap(v)).toList();
  }

  /// Visita geral mais recente de uma família.
  Future<Visita?> ultimaVisitaFamilia(String familiaId) async {
    final db = await dbHelper.database;
    final resultado = await db.query(
      'visita',
      where: 'familia_id = ? AND morador_id IS NULL AND ativo = 1',
      whereArgs: [familiaId],
      orderBy: 'data_visita DESC',
      limit: 1,
    );
    if (resultado.isEmpty) return null;
    return Visita.fromMap(resultado.first);
  }

  /// Visita mais recente de cada domicílio do território (com o resultado),
  /// usada para colorir os pinos do mapa.
  Future<Map<String, Visita>> ultimaVisitaPorDomicilio(
      String territorioId) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT v.* FROM visita v
      INNER JOIN domicilio d ON d.id = v.domicilio_id
      WHERE d.territorio_id = ? AND d.ativo = 1 AND v.ativo = 1
      ORDER BY v.data_visita DESC
    ''', [territorioId]);

    final mapa = <String, Visita>{};
    for (final linha in resultado) {
      final visita = Visita.fromMap(linha);
      mapa.putIfAbsent(visita.domicilioId, () => visita);
    }
    return mapa;
  }

  /// Só as datas, mantido para as telas que ainda usam esse formato.
  Future<Map<String, DateTime>> ultimasVisitasPorTerritorio(
      String territorioId) async {
    final ultimas = await ultimaVisitaPorDomicilio(territorioId);
    return ultimas.map((id, v) => MapEntry(id, v.dataVisita));
  }

  /// Quantidade de visitas por resultado dentro de um período.
  Future<Map<String, int>> contarPorResultado({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final db = await dbHelper.database;
    final resultado = await db.rawQuery('''
      SELECT resultado, COUNT(*) as total FROM visita
      WHERE ativo = 1 AND data_visita >= ? AND data_visita < ?
      GROUP BY resultado
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);

    final mapa = {for (final r in resultadosVisita) r: 0};
    for (final linha in resultado) {
      mapa[linha['resultado'] as String] = (linha['total'] as int?) ?? 0;
    }
    return mapa;
  }
}