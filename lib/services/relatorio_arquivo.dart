import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../database/relatorio_dao.dart';
import 'relatorio_service.dart';

/// Abre a tela de impressão do Android, que permite imprimir ou escolher
/// "Salvar como PDF" e decidir a pasta onde o arquivo fica.
class RelatorioArquivo {
  static Future<void> salvarOuImprimir({
    required DadosRelatorio dados,
    required String nomeTerritorio,
    required String nomeAgente,
    required int ano,
    required int mes,
    bool incluirNomes = false,
  }) async {
    final bytes = Uint8List.fromList(await RelatorioService.montar(
      dados: dados,
      nomeTerritorio: nomeTerritorio,
      nomeAgente: nomeAgente,
      ano: ano,
      mes: mes,
      incluirNomes: incluirNomes,
    ));

    // o Android acrescenta o .pdf sozinho ao salvar
    final nome = RelatorioService.nomeArquivo(
      nomeTerritorio: nomeTerritorio,
      ano: ano,
      mes: mes,
    ).replaceFirst(RegExp(r'\.pdf$'), '');

    await Printing.layoutPdf(
      name: nome,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }
}