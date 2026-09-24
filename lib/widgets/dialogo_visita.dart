import 'package:flutter/material.dart';
import '../models/visita.dart';

Color corResultado(String resultado) {
  switch (resultado) {
    case 'ausente':
      return Colors.amber.shade800;
    case 'recusada':
      return Colors.red.shade600;
    default:
      return Colors.green.shade600;
  }
}

IconData iconeResultado(String resultado) {
  switch (resultado) {
    case 'ausente':
      return Icons.person_off_outlined;
    case 'recusada':
      return Icons.block;
    default:
      return Icons.check_circle_outline;
  }
}

class DadosVisita {
  final String resultado;
  final String? observacoes;
  final DateTime data;

  DadosVisita({required this.resultado, this.observacoes, required this.data});
}

/// Abre o diálogo de visita e devolve o que foi preenchido
/// (ou null se o agente cancelar).
Future<DadosVisita?> mostrarDialogoVisita(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  String resultadoInicial = 'realizada',
  String? observacoesIniciais,
  DateTime? dataInicial,
  bool permitirEditarData = false,
  bool permitirRealizada = true,
}) {
  final obsController = TextEditingController(text: observacoesIniciais ?? '');
  final opcoes = resultadosVisita
      .where((r) => permitirRealizada || r != 'realizada')
      .toList();
  String resultado =
      opcoes.contains(resultadoInicial) ? resultadoInicial : opcoes.first;
  DateTime data = dataInicial ?? DateTime.now();

  return showDialog<DadosVisita>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitulo != null) ...[
                Text(subtitulo,
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
              ],
              const Text('Resultado',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final r in opcoes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setDialog(() => resultado = r),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: resultado == r
                            ? corResultado(r).withValues(alpha: 0.08)
                            : null,
                        border: Border.all(
                          color: resultado == r
                              ? corResultado(r)
                              : Colors.black12,
                          width: resultado == r ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(iconeResultado(r), color: corResultado(r)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(rotulosResultado[r]!,
                                style: const TextStyle(fontSize: 15)),
                          ),
                          if (resultado == r)
                            Icon(Icons.check, color: corResultado(r)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (permitirEditarData)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${data.day.toString().padLeft(2, '0')}/'
                    '${data.month.toString().padLeft(2, '0')}/${data.year}',
                  ),
                  onTap: () async {
                    final escolhida = await showDatePicker(
                      context: context,
                      initialDate: data,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (escolhida != null) {
                      setDialog(() {
                        data = DateTime(escolhida.year, escolhida.month,
                            escolhida.day, data.hour, data.minute);
                      });
                    }
                  },
                ),
              const SizedBox(height: 8),
              TextField(
                controller: obsController,
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              DadosVisita(
                resultado: resultado,
                observacoes: obsController.text.trim().isEmpty
                    ? null
                    : obsController.text.trim(),
                data: data,
              ),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}