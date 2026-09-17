import 'package:sqflite_sqlcipher/sqflite.dart';
import 'database_helper.dart';

/// Métodos compartilhados de controle de sincronização.
class SyncHelper {
  static final _dbHelper = DatabaseHelper.instance;

  /// Registros ainda não enviados ao servidor.
  static Future<List<Map<String, dynamic>>> pendentes(String tabela) async {
    final db = await _dbHelper.database;
    return db.query(tabela, where: 'sincronizado = 0');
  }

  /// Marca registros como enviados com sucesso.
  static Future<void> marcarSincronizados(
      String tabela, List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    final marcadores = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $tabela SET sincronizado = 1 WHERE id IN ($marcadores)',
      ids,
    );
  }

  /// Grava um registro vindo do servidor. Se a versão local for mais
  /// recente e ainda não enviada, mantém a local (última edição vence).
  static Future<void> salvarDoServidor(
    String tabela,
    Map<String, dynamic> dadosLocais,
    DateTime atualizadoRemoto,
  ) async {
    final db = await _dbHelper.database;

    final existente = await db.query(
      tabela,
      where: 'id = ?',
      whereArgs: [dadosLocais['id']],
    );

    if (existente.isNotEmpty) {
      final localTexto = existente.first['atualizado_em'] as String?;
      final sincronizadoLocal = existente.first['sincronizado'] == 1;

      if (!sincronizadoLocal && localTexto != null && localTexto.isNotEmpty) {
        final localData = DateTime.tryParse(localTexto);
        if (localData != null && localData.isAfter(atualizadoRemoto)) {
          return;
        }
      }
    }

    await db.insert(
      tabela,
      {...dadosLocais, 'sincronizado': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> totalPendentes() async {
    final db = await _dbHelper.database;
    int total = 0;
    for (final tabela in ['domicilio', 'familia', 'morador', 'visita']) {
      final r = await db
          .rawQuery('SELECT COUNT(*) as t FROM $tabela WHERE sincronizado = 0');
      total += (r.first['t'] as int?) ?? 0;
    }
    return total;
  }
}