import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/relatorio_dao.dart';

const List<String> _comorbidadesRelatorio = [
  'hipertensao',
  'diabetes',
  'obesidade',
  'cardiopatia',
  'problema_respiratorio',
];

/// Monta os dados do relatório a partir do servidor, para o coordenador.
/// Aceita uma microárea específica ou todas (consolidado).
class RelatorioConsultaService {
  static final _cliente = Supabase.instance.client;

  static Future<DadosRelatorio> gerar({
    String? territorioId, // null = todas as microáreas
    required int ano,
    required int mes,
  }) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(mes == 12 ? ano + 1 : ano, mes == 12 ? 1 : mes + 1, 1);
    final inicioAnterior =
        DateTime(mes == 1 ? ano - 1 : ano, mes == 1 ? 12 : mes - 1, 1);

    // ---------- domicílios ----------
    var consultaDom = _cliente
        .from('domicilio')
        .select('id, rua, numero, territorio_id')
        .eq('ativo', true);
    if (territorioId != null) {
      consultaDom = consultaDom.eq('territorio_id', territorioId);
    }
    final domicilios = await consultaDom;

    final idsDomicilios =
        domicilios.map<String>((d) => d['id'] as String).toList();

    final enderecos = <String, String>{
      for (final d in domicilios)
        d['id'] as String: '${d['rua']}, ${d['numero']}'
    };

    if (idsDomicilios.isEmpty) {
      return _vazio();
    }

    // ---------- famílias ----------
    final familias = await _cliente
        .from('familia')
        .select('id, domicilio_id')
        .inFilter('domicilio_id', idsDomicilios)
        .eq('ativo', true);

    final idsFamilias = familias.map<String>((f) => f['id'] as String).toList();
    final comFamilia =
        familias.map<String>((f) => f['domicilio_id'] as String).toSet();

    // ---------- visitas do mês ----------
    final visitasMes = await _cliente
        .from('visita')
        .select('domicilio_id, familia_id, morador_id, data_visita, resultado')
        .inFilter('domicilio_id', idsDomicilios)
        .eq('ativo', true)
        .gte('data_visita', inicio.toIso8601String())
        .lt('data_visita', fim.toIso8601String())
        .order('data_visita');

    int comContato = 0, ausentes = 0, recusadas = 0;
    final porDomicilio = <String, bool>{}; // teve contato?
    final familiasComContato = <String>{};
    final moradoresComContato = <String>{};
    final lista = <VisitaRelatorio>[];

    for (final v in visitasMes) {
      final resultado = (v['resultado'] as String?) ?? 'realizada';
      final domicilioId = v['domicilio_id'] as String;
      final teveContato = resultado == 'realizada';

      switch (resultado) {
        case 'ausente':
          ausentes++;
          break;
        case 'recusada':
          recusadas++;
          break;
        default:
          comContato++;
      }

      porDomicilio[domicilioId] =
          (porDomicilio[domicilioId] ?? false) || teveContato;

      if (teveContato) {
        if (v['morador_id'] != null) {
          moradoresComContato.add(v['morador_id'] as String);
        } else if (v['familia_id'] != null) {
          familiasComContato.add(v['familia_id'] as String);
        }
      }

      final tipo = v['morador_id'] != null
          ? 'Individual'
          : v['familia_id'] == null
              ? 'Casa não cadastrada'
              : 'Família';

      lista.add(VisitaRelatorio(
        data: DateTime.parse(v['data_visita'] as String),
        endereco: enderecos[domicilioId] ?? '-',
        resultado: resultado,
        tipo: tipo,
      ));
    }

    final casasSemContato = porDomicilio.values.where((teve) => !teve).length;

    // ---------- visitas do mês anterior ----------
    final visitasAnterior = await _cliente
        .from('visita')
        .select('id')
        .inFilter('domicilio_id', idsDomicilios)
        .eq('ativo', true)
        .gte('data_visita', inicioAnterior.toIso8601String())
        .lt('data_visita', inicio.toIso8601String());

    // ---------- últimos seis meses, para o gráfico ----------
    final historico = <VisitasPorMes>[];
    for (var passo = 5; passo >= 0; passo--) {
      final refAno = mes - passo < 1 ? ano - 1 : ano;
      final refMes = mes - passo < 1 ? mes - passo + 12 : mes - passo;
      final ini = DateTime(refAno, refMes, 1);
      final fimMes = DateTime(
          refMes == 12 ? refAno + 1 : refAno, refMes == 12 ? 1 : refMes + 1, 1);

      final r = await _cliente
          .from('visita')
          .select('id')
          .inFilter('domicilio_id', idsDomicilios)
          .eq('ativo', true)
          .gte('data_visita', ini.toIso8601String())
          .lt('data_visita', fimMes.toIso8601String());

      historico.add(VisitasPorMes(ano: refAno, mes: refMes, total: r.length));
    }

    // ---------- pendentes de visita (30 dias) ----------
    final limite = DateTime.now().subtract(const Duration(days: 30));
    final visitasRecentes = await _cliente
        .from('visita')
        .select('domicilio_id')
        .inFilter('domicilio_id', idsDomicilios)
        .eq('ativo', true)
        .gte('data_visita', limite.toIso8601String());

    final visitadosRecente =
        visitasRecentes.map<String>((v) => v['domicilio_id'] as String).toSet();

    // ---------- moradores ----------
    final moradores = idsFamilias.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(await _cliente
            .from('morador')
            .select(
                'id, nome, familia_id, gestante, acamado, data_nascimento, comorbidades')
            .inFilter('familia_id', idsFamilias)
            .eq('ativo', true)
            .order('nome'));

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
      final nome = m['nome'] as String;
      final acompanhado = moradoresComContato.contains(m['id']) ||
          familiasComContato.contains(m['familia_id']);

      totalGeral++;
      if (acompanhado) acompGeral++;

      if (m['gestante'] == true) {
        totalGest++;
        if (acompanhado) {
          acompGest++;
        } else {
          faltamGest.add(nome);
        }
      }
      if (m['acamado'] == true) {
        totalAca++;
        if (acompanhado) {
          acompAca++;
        } else {
          faltamAca.add(nome);
        }
      }

      final nascimento = DateTime.parse(m['data_nascimento']);
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

      final comorbidades = ((m['comorbidades'] as String?) ?? '')
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty);
      for (final c in comorbidades) {
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
      casasSemContato: casasSemContato,
      totalVisitasMesAnterior: visitasAnterior.length,
      comContatoMesAnterior: 0,
      historico: historico,
      totalDomicilios: idsDomicilios.length,
      totalMoradores: totalGeral,
      naoCadastradas:
          idsDomicilios.where((id) => !comFamilia.contains(id)).length,
      pendentesVisita:
          idsDomicilios.where((id) => !visitadosRecente.contains(id)).length,
      moradores: Acompanhamento(acompGeral, totalGeral),
      gestantes: Acompanhamento(acompGest, totalGest, faltamGest),
      criancas: Acompanhamento(acompCri, totalCri, faltamCri),
      idosos: Acompanhamento(acompIdo, totalIdo, faltamIdo),
      acamados: Acompanhamento(acompAca, totalAca, faltamAca),
      comorbidades: {
        for (final c in _comorbidadesRelatorio)
          c: Acompanhamento(acompComorb[c]!, totalComorb[c]!, faltamComorb[c]!)
      },
      visitas: lista,
    );
  }

  static DadosRelatorio _vazio() => DadosRelatorio(
        totalVisitas: 0,
        visitasComContato: 0,
        tentativasAusentes: 0,
        visitasRecusadas: 0,
        casasSemContato: 0,
        totalVisitasMesAnterior: 0,
        comContatoMesAnterior: 0,
        historico: const [],
        totalDomicilios: 0,
        totalMoradores: 0,
        naoCadastradas: 0,
        pendentesVisita: 0,
        moradores: const Acompanhamento(0, 0),
        gestantes: const Acompanhamento(0, 0),
        criancas: const Acompanhamento(0, 0),
        idosos: const Acompanhamento(0, 0),
        acamados: const Acompanhamento(0, 0),
        comorbidades: {
          for (final c in _comorbidadesRelatorio) c: const Acompanhamento(0, 0)
        },
        visitas: const [],
      );
}