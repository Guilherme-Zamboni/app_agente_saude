import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/relatorio_dao.dart';
import '../models/visita.dart';
import '../screens/tela_cadastro_morador.dart' show comorbidadesLabels;

const List<String> nomesMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

class RelatorioService {
  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String nomeArquivo({
    required String nomeTerritorio,
    required int ano,
    required int mes,
  }) =>
      'relatorio_${nomeTerritorio.replaceAll(RegExp(r'[^\w]'), '_')}'
      '_${mes.toString().padLeft(2, '0')}_$ano.pdf';

  /// Monta o PDF e devolve os bytes.
  static Future<List<int>> montar({
    required DadosRelatorio dados,
    required String nomeTerritorio,
    required String nomeAgente,
    required int ano,
    required int mes,
    bool incluirNomes = false,
  }) async {
    final documento = pw.Document();
    final mesNome = nomesMeses[mes - 1];
    final mesAnterior = nomesMeses[(mes == 1 ? 12 : mes - 1) - 1];

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text('$nomeTerritorio • $mesNome/$ano',
                    style: const pw.TextStyle(fontSize: 9)),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // ---------- cabeçalho ----------
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Relatório Mensal de Visitas',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Microárea: $nomeTerritorio',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Agente: $nomeAgente',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Período: $mesNome de $ano',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Emitido em ${_data(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),

          // ---------- visitas do mês ----------
          _titulo('Visitas no mês'),
          _tabela([
            ['Total de visitas realizadas', '${dados.totalVisitas}'],
            ['Idas em que os moradores estavam ausentes',
                '${dados.tentativasAusentes}'],
            ['Visitas recusadas', '${dados.visitasRecusadas}'],
            ['Casas sem contato no mês', '${dados.casasSemContato}'],
          ]),
          pw.SizedBox(height: 6),
          _comparativo(dados, mesAnterior),
          pw.SizedBox(height: 12),
          _graficoHistorico(dados),
          pw.SizedBox(height: 12),
          _graficoResultados(dados),
          pw.SizedBox(height: 6),
          pw.Text(
            'Cada ida à casa é contabilizada, mesmo que o agente tenha '
            'retornado ao mesmo domicílio mais de uma vez. "Casas sem contato" '
            'são os domicílios visitados no mês em que não foi possível falar '
            'com ninguém.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),

          // ---------- cadastros ----------
          _titulo('Cadastros total'),
          _tabela([
            ['Domicílios cadastrados', '${dados.totalDomicilios}'],
            ['Moradores cadastrados', '${dados.totalMoradores}'],
          ]),

          // ---------- situação da área ----------
          _titulo('Situação atual da microárea'),
          _tabela([
            ['Total de domicílios', '${dados.totalDomicilios}'],
            ['Casas não cadastradas', '${dados.naoCadastradas}'],
            ['Casas sem contato no mês', '${dados.casasSemContato}'],
            ['Domicílios pendentes de visita (30 dias)',
                '${dados.pendentesVisita}'],
          ]),

          // ---------- população ----------
          _titulo('População acompanhada no mês'),
          _tabela([
            ['Moradores', dados.moradores.textoComPercentual],
            ['Gestantes', dados.gestantes.textoComPercentual],
            ['Crianças menores de 2 anos', dados.criancas.textoComPercentual],
            ['Idosos (60 anos ou mais)', dados.idosos.textoComPercentual],
            ['Acamados', dados.acamados.textoComPercentual],
          ]),
          pw.Text(
            'Os números indicam quantas pessoas de cada grupo receberam visita '
            'com contato no mês, em relação ao total cadastrado na microárea.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),

          // ---------- comorbidades ----------
          _titulo('Comorbidades acompanhadas no mês'),
          _tabela([
            for (final e in dados.comorbidades.entries)
              [comorbidadesLabels[e.key] ?? e.key, e.value.textoComPercentual],
          ]),

          // ---------- lista nominal (opcional) ----------
          if (incluirNomes) ..._secaoNaoVisitados(dados),

          // ---------- lista de visitas ----------
          _titulo('Detalhamento das visitas'),
          if (dados.visitas.isEmpty)
            pw.Text('Nenhuma visita registrada neste mês.',
                style: const pw.TextStyle(fontSize: 11))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Data', 'Endereço', 'Tipo', 'Resultado'],
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(2),
              },
              data: dados.visitas
                  .map((v) => [
                        _data(v.data),
                        v.endereco,
                        v.tipo,
                        rotulosResultado[v.resultado] ?? v.resultado,
                      ])
                  .toList(),
            ),

          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Text(
            'Documento gerado pelo aplicativo de territorialização e '
            'acompanhamento de moradores.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          if (incluirNomes)
            pw.Text(
              'Este relatório contém nomes de moradores. Trata-se de documento '
              'de uso interno da unidade de saúde, sujeito a sigilo.',
              style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.red800,
                  fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );

    return documento.save();
  }

  /// Abre a tela de compartilhamento do sistema.
  static Future<void> compartilhar({
    required DadosRelatorio dados,
    required String nomeTerritorio,
    required String nomeAgente,
    required int ano,
    required int mes,
    bool incluirNomes = false,
  }) async {
    final bytes = await montar(
      dados: dados,
      nomeTerritorio: nomeTerritorio,
      nomeAgente: nomeAgente,
      ano: ano,
      mes: mes,
      incluirNomes: incluirNomes,
    );

    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename:
          nomeArquivo(nomeTerritorio: nomeTerritorio, ano: ano, mes: mes),
    );
  }

  /// Barras com o total de visitas dos últimos seis meses.
  static pw.Widget _graficoHistorico(DadosRelatorio dados) {
    if (dados.historico.isEmpty) return pw.SizedBox();

    final maior = dados.historico
        .map((h) => h.total)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (maior == 0) return pw.SizedBox();

    const alturaMax = 70.0;
    final ultimo = dados.historico.last;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Visitas nos últimos 6 meses',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.SizedBox(
          height: alturaMax + 30,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: dados.historico.map((h) {
              final altura = (h.total / maior) * alturaMax;
              final atual = h.ano == ultimo.ano && h.mes == ultimo.mes;
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('${h.total}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    width: 26,
                    height: altura < 2 ? 2 : altura,
                    color: atual ? PdfColors.teal600 : PdfColors.teal200,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(nomesMeses[h.mes - 1].substring(0, 3),
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Barra horizontal com a proporção dos resultados do mês.
  static pw.Widget _graficoResultados(DadosRelatorio dados) {
    final total = dados.totalVisitas;
    if (total == 0) return pw.SizedBox();

    final comContato = dados.visitasComContato;
    final ausentes = dados.tentativasAusentes;
    final recusadas = dados.visitasRecusadas;

    pw.Widget faixa(int valor, PdfColor cor) {
      if (valor == 0) return pw.SizedBox();
      return pw.Expanded(
        flex: valor,
        child: pw.Container(height: 18, color: cor),
      );
    }

    pw.Widget legenda(String texto, int valor, PdfColor cor) {
      final p = (valor / total * 100).toStringAsFixed(0);
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(width: 8, height: 8, color: cor),
          pw.SizedBox(width: 3),
          pw.Text('$texto: $valor ($p%)',
              style: const pw.TextStyle(fontSize: 8)),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Resultado das visitas do mês',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          faixa(comContato, PdfColors.green400),
          faixa(ausentes, PdfColors.amber400),
          faixa(recusadas, PdfColors.red300),
        ]),
        pw.SizedBox(height: 5),
        pw.Wrap(
          spacing: 12,
          runSpacing: 3,
          children: [
            legenda('Atendidas', comContato, PdfColors.green400),
            legenda('Ausentes', ausentes, PdfColors.amber400),
            legenda('Recusadas', recusadas, PdfColors.red300),
          ],
        ),
      ],
    );
  }

  static List<pw.Widget> _secaoNaoVisitados(DadosRelatorio dados) {
    final grupos = <String, List<String>>{
      'Gestantes': dados.gestantes.naoVisitados,
      'Crianças menores de 2 anos': dados.criancas.naoVisitados,
      'Idosos (60 anos ou mais)': dados.idosos.naoVisitados,
      'Acamados': dados.acamados.naoVisitados,
      for (final e in dados.comorbidades.entries)
        comorbidadesLabels[e.key] ?? e.key: e.value.naoVisitados,
    }..removeWhere((_, lista) => lista.isEmpty);

    if (grupos.isEmpty) {
      return [
        _titulo('Grupos prioritários sem visita no mês'),
        pw.Text(
            'Todos os moradores dos grupos prioritários receberam visita '
            'no período.',
            style: const pw.TextStyle(fontSize: 11)),
      ];
    }

    return [
      _titulo('Grupos prioritários sem visita no mês'),
      for (final e in grupos.entries) ...[
        pw.SizedBox(height: 6),
        pw.Text('${e.key} (${e.value.length})',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(e.value.join(' • '), style: const pw.TextStyle(fontSize: 10)),
      ],
    ];
  }

  static pw.Widget _comparativo(DadosRelatorio dados, String mesAnterior) {
    final diferenca = dados.diferencaVisitas;
    final anterior = dados.totalVisitasMesAnterior;

    if (anterior == 0 && dados.totalVisitas == 0) return pw.SizedBox();

    final texto = diferenca == 0
        ? 'Mesmo número de visitas de $mesAnterior ($anterior).'
        : diferenca > 0
            ? '$diferenca visita(s) a mais que em $mesAnterior ($anterior).'
            : '${diferenca.abs()} visita(s) a menos que em $mesAnterior ($anterior).';

    final cor = diferenca >= 0 ? PdfColors.green800 : PdfColors.orange800;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(texto, style: pw.TextStyle(fontSize: 10, color: cor)),
    );
  }

  static pw.Widget _titulo(String texto) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(texto,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _tabela(List<List<String>> linhas) =>
      pw.TableHelper.fromTextArray(
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight
        },
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1.4),
        },
        data: linhas,
      );
}