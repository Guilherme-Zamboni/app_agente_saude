import '../database/database_helper.dart';

/// Quantos de um grupo foram efetivamente acompanhados no mês.
class Acompanhamento {
  final int acompanhados;
  final int total;
  final List<String> naoVisitados;

  const Acompanhamento(this.acompanhados, this.total,
      [this.naoVisitados = const []]);

  String get texto => '$acompanhados/$total';

  String get textoComPercentual {
    if (total == 0) return '0/0';
    final p = (acompanhados / total * 100).toStringAsFixed(0);
    return '$acompanhados/$total ($p%)';
  }
}

class VisitasPorMes {
  final int ano;
  final int mes;
  final int total;

  VisitasPorMes({required this.ano, required this.mes, required this.total});
}

class DadosRelatorio {
  // visitas do mês
  final int totalVisitas;
  final int visitasComContato;
  final int tentativasAusentes;
  final int visitasRecusadas;
  final int casasSemContato;

  // mês anterior, para comparação
  final int totalVisitasMesAnterior;
  final int comContatoMesAnterior;

  // últimos seis meses, para o gráfico (mais antigo primeiro)
  final List<VisitasPorMes> historico;

  // cadastros acumulados
  final int totalDomicilios;
  final int totalMoradores;

  // situação da microárea
  final int naoCadastradas;
  final int pendentesVisita;

  // população acompanhada no mês
  final Acompanhamento moradores;
  final Acompanhamento gestantes;
  final Acompanhamento criancas;
  final Acompanhamento idosos;
  final Acompanhamento acamados;
  final Map<String, Acompanhamento> comorbidades;

  final List<VisitaRelatorio> visitas;

  DadosRelatorio({
    required this.totalVisitas,
    required this.visitasComContato,
    required this.tentativasAusentes,
    required this.visitasRecusadas,
    required this.casasSemContato,
    required this.totalVisitasMesAnterior,
    required this.comContatoMesAnterior,
    required this.historico,
    required this.totalDomicilios,
    required this.totalMoradores,
    required this.naoCadastradas,
    required this.pendentesVisita,
    required this.moradores,
    required this.gestantes,
    required this.criancas,
    required this.idosos,
    required this.acamados,
    required this.comorbidades,
    required this.visitas,
  });

  int get diferencaVisitas => totalVisitas - totalVisitasMesAnterior;
}

class VisitaRelatorio {
  final DateTime data;
  final String endereco;
  final String resultado;
  final String tipo;

  VisitaRelatorio({
    required this.data,
    required this.endereco,
    required this.resultado,
    required this.tipo,
  });
}

const List<String> _comorbidadesRelatorio = [
  'hipertensao',
  'diabetes',
  'obesidade',
  'cardiopatia',
  'problema_respiratorio',
];

class RelatorioDao {
  final dbHelper = DatabaseHelper.instance;

  Future<DadosRelatorio> gerar({
    required String territorioId,
    required int ano,
    required int mes,
  }) async {
    final db = await dbHelper.database;
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(mes == 12 ? ano + 1 : ano, mes == 12 ? 1 : mes + 1, 1);
    final i = inicio.toIso8601String();
    final f = fim.toIso8601String();

    // --- visitas do mês, por resultado ---
    final porResultado = await db.rawQuery('''
      SELECT v.resultado, COUNT(*) as total
      FROM visita v
      INNER JOIN domicilio d ON d.id = v.domicilio_id
      WHERE d.territorio_id = ? AND v.ativo = 1
        AND v.data_visita >= ? AND v.data_visita < ?
      GROUP BY v.resultado
    ''', [territorioId, i, f]);

    int comContato = 0, ausentes = 0, recusadas = 0;
    for (final linha in porResultado) {
      final total = (linha['total'] as int?) ?? 0;
      switch (linha['resultado']) {
        case 'ausente':
          ausentes = total;
          break;
        case 'recusada':
          recusadas = total;
          break;
        default:
          comContato = total;
      }
    }

    // --- mês anterior, para comparação ---
    final inicioAnterior =
        DateTime(mes == 1 ? ano - 1 : ano, mes == 1 ? 12 : mes - 1, 1);
    final anterior = await db.rawQuery('''
      SELECT COUNT(*) as total,
             SUM(CASE WHEN v.resultado = 'realizada' THEN 1 ELSE 0 END)
               as com_contato
      FROM visita v
      INNER JOIN domicilio d ON d.id = v.domicilio_id
      WHERE d.territorio_id = ? AND v.ativo = 1
        AND v.data_visita >= ? AND v.data_visita < ?
    ''', [territorioId, inicioAnterior.toIso8601String(), i]);

    // --- últimos seis meses, para o gráfico ---
    final historico = <VisitasPorMes>[];
    for (var passo = 5; passo >= 0; passo--) {
      final refAno = mes - passo < 1 ? ano - 1 : ano;
      final refMes = mes - passo < 1 ? mes - passo + 12 : mes - passo;
      final ini = DateTime(refAno, refMes, 1);
      final fimMes = DateTime(
          refMes == 12 ? refAno + 1 : refAno, refMes == 12 ? 1 : refMes + 1, 1);

      final r = await db.rawQuery('''
        SELECT COUNT(*) as total FROM visita v
        INNER JOIN domicilio d ON d.id = v.domicilio_id
        WHERE d.territorio_id = ? AND v.ativo = 1
          AND v.data_visita >= ? AND v.data_visita < ?
      ''', [territorioId, ini.toIso8601String(), fimMes.toIso8601String()]);

      historico.add(VisitasPorMes(
        ano: refAno,
        mes: refMes,
        total: (r.first['total'] as int?) ?? 0,
      ));
    }

    // casas em que houve ida no mês, mas nenhuma visita com contato
    final semContato = await db.rawQuery('''
      SELECT COUNT(*) as total FROM (
        SELECT v.domicilio_id
        FROM visita v
        INNER JOIN domicilio d ON d.id = v.domicilio_id
        WHERE d.territorio_id = ? AND v.ativo = 1
          AND v.data_visita >= ? AND v.data_visita < ?
        GROUP BY v.domicilio_id
        HAVING SUM(CASE WHEN v.resultado = 'realizada' THEN 1 ELSE 0 END) = 0
      )
    ''', [territorioId, i, f]);

    // --- lista das visitas do mês ---
    final listaVisitas = await db.rawQuery('''
      SELECT v.data_visita, v.resultado, v.morador_id, v.familia_id,
             d.rua, d.numero
      FROM visita v
      INNER JOIN domicilio d ON d.id = v.domicilio_id
      WHERE d.territorio_id = ? AND v.ativo = 1
        AND v.data_visita >= ? AND v.data_visita < ?
      ORDER BY v.data_visita
    ''', [territorioId, i, f]);

    final visitas = listaVisitas.map((v) {
      final tipo = v['morador_id'] != null
          ? 'Individual'
          : v['familia_id'] == null
              ? 'Casa não cadastrada'
              : 'Família';
      return VisitaRelatorio(
        data: DateTime.parse(v['data_visita'] as String),
        endereco: '${v['rua']}, ${v['numero']}',
        resultado: (v['resultado'] as String?) ?? 'realizada',
        tipo: tipo,
      );
    }).toList();

    // --- totais cadastrados ---
    final totalDom = await db.rawQuery(
      'SELECT COUNT(*) as total FROM domicilio WHERE territorio_id = ? AND ativo = 1',
      [territorioId],
    );

    final semFamilia = await db.rawQuery('''
      SELECT COUNT(*) as total FROM domicilio d
      WHERE d.territorio_id = ? AND d.ativo = 1
        AND NOT EXISTS (
          SELECT 1 FROM familia fa WHERE fa.domicilio_id = d.id AND fa.ativo = 1
        )
    ''', [territorioId]);

    final limitePendente =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final pendentes = await db.rawQuery('''
      SELECT COUNT(*) as total FROM domicilio d
      WHERE d.territorio_id = ? AND d.ativo = 1
        AND NOT EXISTS (
          SELECT 1 FROM visita v
          WHERE v.domicilio_id = d.id AND v.ativo = 1
            AND v.data_visita >= ?
        )
    ''', [territorioId, limitePendente]);

    // --- moradores e quem foi acompanhado no mês ---
    final moradores = await db.rawQuery('''
      SELECT m.id, m.nome, m.gestante, m.acamado, m.data_nascimento,
             m.comorbidades,
             MAX(CASE WHEN v.resultado = 'realizada' THEN 1 ELSE 0 END)
               as acompanhado
      FROM morador m
      INNER JOIN familia fa ON fa.id = m.familia_id AND fa.ativo = 1
      INNER JOIN domicilio d ON d.id = fa.domicilio_id AND d.ativo = 1
      LEFT JOIN visita v
        ON (v.morador_id = m.id
            OR (v.familia_id = fa.id AND v.morador_id IS NULL))
        AND v.ativo = 1 AND v.data_visita >= ? AND v.data_visita < ?
      WHERE d.territorio_id = ? AND m.ativo = 1
      GROUP BY m.id
      ORDER BY m.nome
    ''', [i, f, territorioId]);

    final agora = DateTime.now();

    int totalGeral = 0, acompGeral = 0;
    int totalGest = 0, acompGest = 0;
    int totalCri = 0, acompCri = 0;
    int totalIdo = 0, acompIdo = 0;
    int totalAca = 0, acompAca = 0;
    final faltamGest = <String>[];
    final faltamCri = <String>[];
    final faltamIdo = <String>[];
    final faltamAca = <String>[];
    final totalComorb = {for (final c in _comorbidadesRelatorio) c: 0};
    final acompComorb = {for (final c in _comorbidadesRelatorio) c: 0};
    final faltamComorb = {
      for (final c in _comorbidadesRelatorio) c: <String>[]
    };

    for (final m in moradores) {
      final acompanhado = (m['acompanhado'] as int? ?? 0) == 1;
      final nome = m['nome'] as String;

      totalGeral++;
      if (acompanhado) acompGeral++;

      if (m['gestante'] == 1) {
        totalGest++;
        if (acompanhado) {
          acompGest++;
        } else {
          faltamGest.add(nome);
        }
      }
      if (m['acamado'] == 1) {
        totalAca++;
        if (acompanhado) {
          acompAca++;
        } else {
          faltamAca.add(nome);
        }
      }

      final nascimento = DateTime.parse(m['data_nascimento'] as String);
      int idade = agora.year - nascimento.year;
      if (agora.month < nascimento.month ||
          (agora.month == nascimento.month && agora.day < nascimento.day)) {
        idade--;
      }
      if (idade < 2) {
        totalCri++;
        if (acompanhado) {
          acompCri++;
        } else {
          faltamCri.add(nome);
        }
      }
      if (idade >= 60) {
        totalIdo++;
        if (acompanhado) {
          acompIdo++;
        } else {
          faltamIdo.add(nome);
        }
      }

      final lista = ((m['comorbidades'] as String?) ?? '')
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty);
      for (final c in lista) {
        if (!totalComorb.containsKey(c)) continue;
        totalComorb[c] = totalComorb[c]! + 1;
        if (acompanhado) {
          acompComorb[c] = acompComorb[c]! + 1;
        } else {
          faltamComorb[c]!.add(nome);
        }
      }
    }

    return DadosRelatorio(
      totalVisitas: comContato + ausentes + recusadas,
      visitasComContato: comContato,
      tentativasAusentes: ausentes,
      visitasRecusadas: recusadas,
      casasSemContato: (semContato.first['total'] as int?) ?? 0,
      totalVisitasMesAnterior: (anterior.first['total'] as int?) ?? 0,
      comContatoMesAnterior: (anterior.first['com_contato'] as int?) ?? 0,
      historico: historico,
      totalDomicilios: (totalDom.first['total'] as int?) ?? 0,
      totalMoradores: totalGeral,
      naoCadastradas: (semFamilia.first['total'] as int?) ?? 0,
      pendentesVisita: (pendentes.first['total'] as int?) ?? 0,
      moradores: Acompanhamento(acompGeral, totalGeral),
      gestantes: Acompanhamento(acompGest, totalGest, faltamGest),
      criancas: Acompanhamento(acompCri, totalCri, faltamCri),
      idosos: Acompanhamento(acompIdo, totalIdo, faltamIdo),
      acamados: Acompanhamento(acompAca, totalAca, faltamAca),
      comorbidades: {
        for (final c in _comorbidadesRelatorio)
          c: Acompanhamento(acompComorb[c]!, totalComorb[c]!, faltamComorb[c]!)
      },
      visitas: visitas,
    );
  }
}