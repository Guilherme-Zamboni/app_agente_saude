import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/database_helper.dart';
import '../database/sync_helper.dart';
import '../models/domicilio.dart';
import '../models/familia.dart';
import '../models/morador.dart';
import '../models/visita.dart';

class ResultadoSync {
  final bool sucesso;
  final int enviados;
  final int recebidos;
  final String? erro;

  ResultadoSync({
    required this.sucesso,
    this.enviados = 0,
    this.recebidos = 0,
    this.erro,
  });
}

class SyncService {
  static final _cliente = Supabase.instance.client;
  static final _dbHelper = DatabaseHelper.instance;

  static bool _emAndamento = false;
  static bool get emAndamento => _emAndamento;

  /// Executa a sincronização completa: envia pendências e baixa novidades.
  static Future<ResultadoSync> sincronizar(String territorioId) async {
    if (_emAndamento) {
      return ResultadoSync(
          sucesso: false, erro: 'Sincronização já em andamento');
    }

    _emAndamento = true;

    try {
      final enviados = await _enviarPendentes();
      final recebidos = await _baixarDoServidor(territorioId);

      await _dbHelper.registrarSincronizacao(DateTime.now());

      return ResultadoSync(
        sucesso: true,
        enviados: enviados,
        recebidos: recebidos,
      );
    } on PostgrestException catch (e) {
      return ResultadoSync(sucesso: false, erro: e.message);
    } catch (e) {
      return ResultadoSync(
        sucesso: false,
        erro: 'Não foi possível conectar ao servidor',
      );
    } finally {
      _emAndamento = false;
    }
  }

  /// Garante que o território do agente exista no banco local,
  /// já que ele é criado pelo coordenador diretamente no servidor.
  static Future<void> garantirTerritorioLocal(
      Map<String, dynamic> territorio) async {
    final db = await _dbHelper.database;
    await db.insert(
      'territorio',
      {
        'id': territorio['id'],
        'nome': territorio['nome'],
        'agente_id': territorio['agente_id'] ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- ENVIO ----------
  // A ordem importa: cada tabela depende da anterior existir no servidor.

  static Future<int> _enviarPendentes() async {
    int total = 0;
    total += await _enviarTabela(
      'domicilio',
      (m) => Domicilio.fromMap(m).toSupabase(),
    );
    total += await _enviarTabela(
      'familia',
      (m) => Familia.fromMap(m).toSupabase(),
    );
    total += await _enviarTabela(
      'morador',
      (m) => Morador.fromMap(m).toSupabase(),
    );
    total += await _enviarTabela(
      'visita',
      (m) => Visita.fromMap(m).toSupabase(),
    );
    return total;
  }

  static Future<int> _enviarTabela(
    String tabela,
    Map<String, dynamic> Function(Map<String, dynamic>) converter,
  ) async {
    final pendentes = await SyncHelper.pendentes(tabela);
    if (pendentes.isEmpty) return 0;

    final usuarioId = _cliente.auth.currentUser?.id;
    final enviadosComSucesso = <String>[];

    // Envia um a um para que uma falha isolada não derrube o lote inteiro
    for (final registro in pendentes) {
      try {
        final dados = converter(registro);
        if (tabela == 'visita' && usuarioId != null) {
          dados['registrado_por'] = usuarioId;
        }
        await _cliente.from(tabela).upsert(dados);
        enviadosComSucesso.add(registro['id'] as String);
      } catch (e) {
        // ignore: avoid_print
        print('>>> FALHA ao enviar $tabela id=${registro['id']}: $e');
      }
    }

    await SyncHelper.marcarSincronizados(tabela, enviadosComSucesso);
    return enviadosComSucesso.length;
  }

  // ---------- RECEBIMENTO ----------

  static Future<int> _baixarDoServidor(String territorioId) async {
    int total = 0;

    final domicilios = await _cliente
        .from('domicilio')
        .select()
        .eq('territorio_id', territorioId);

    final idsDomicilios = <String>[];
    for (final d in domicilios) {
      idsDomicilios.add(d['id'] as String);
      await SyncHelper.salvarDoServidor(
        'domicilio',
        Domicilio.fromMap(d).toMap(),
        _dataDe(d['atualizado_em']),
      );
      total++;
    }

    if (idsDomicilios.isEmpty) return total;

    // Visitas vêm pelo domicílio, incluindo as tentativas em casas sem família
    final visitas = await _cliente
        .from('visita')
        .select()
        .inFilter('domicilio_id', idsDomicilios);

    for (final v in visitas) {
      await SyncHelper.salvarDoServidor(
        'visita',
        Visita.fromMap(v).toMap(),
        _dataDe(v['atualizado_em']),
      );
      total++;
    }

    final familias = await _cliente
        .from('familia')
        .select()
        .inFilter('domicilio_id', idsDomicilios);

    final idsFamilias = <String>[];
    for (final f in familias) {
      idsFamilias.add(f['id'] as String);
      await SyncHelper.salvarDoServidor(
        'familia',
        Familia.fromMap(f).toMap(),
        _dataDe(f['atualizado_em']),
      );
      total++;
    }

    if (idsFamilias.isEmpty) return total;

    final moradores = await _cliente
        .from('morador')
        .select()
        .inFilter('familia_id', idsFamilias);

    for (final m in moradores) {
      await SyncHelper.salvarDoServidor(
        'morador',
        Morador.fromMap(m).toMap(),
        _dataDe(m['atualizado_em']),
      );
      total++;
    }

    return total;
  }

  static DateTime _dataDe(dynamic valor) {
    if (valor == null) return DateTime(2000);
    return DateTime.tryParse(valor.toString()) ?? DateTime(2000);
  }

  // ---------- APOIO PARA A INTERFACE ----------

  static Future<int> pendentes() => SyncHelper.totalPendentes();

  static Future<DateTime?> ultimaSincronizacao() =>
      _dbHelper.ultimaSincronizacao();
}