import 'package:flutter/material.dart';
import '../services/consulta_service.dart';
import '../widgets/dialogo_visita.dart';
import 'tela_cadastro_morador.dart' show comorbidadesLabels;
import '../models/visita.dart';

class TelaFichaConsulta extends StatefulWidget {
  final String moradorId;
  final String familiaId;
  final String nomeMorador;

  const TelaFichaConsulta({
    super.key,
    required this.moradorId,
    required this.familiaId,
    required this.nomeMorador,
  });

  @override
  State<TelaFichaConsulta> createState() => _TelaFichaConsultaState();
}

class _TelaFichaConsultaState extends State<TelaFichaConsulta> {
  late Future<Map<String, dynamic>?> _fichaFuture;
  late Future<List<Map<String, dynamic>>> _visitasFuture;

  @override
  void initState() {
    super.initState();
    _fichaFuture = ConsultaService.fichaCompleta(widget.moradorId);
    _visitasFuture = ConsultaService.historicoVisitas(
      moradorId: widget.moradorId,
      familiaId: widget.familiaId,
    );
  }

  int _idade(DateTime nascimento) {
    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    return idade;
  }

  String _formatarData(DateTime data, {bool comHora = true}) {
    final base = '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
    if (!comHora) return base;
    return '$base às ${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeMorador),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6, left: 16),
            child: SizedBox(
              width: double.infinity,
              child: Text('Somente leitura',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fichaFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final m = snapshot.data;
          if (m == null) {
            return const Center(child: Text('Morador não encontrado.'));
          }

          final nascimento = DateTime.parse(m['data_nascimento']);
          final comorbidadesTexto = (m['comorbidades'] as String?) ?? '';
          final comorbidades = comorbidadesTexto.isEmpty
              ? <String>[]
              : comorbidadesTexto.split(',');
          final familia = m['familia'];
          final domicilio = familia?['domicilio'];
          final gestante = m['gestante'] == true;
          final acamado = m['acamado'] == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _linha('Nome', m['nome']),
                      _linha('Nome da mãe', m['nome_da_mae']),
                      _linha('Nascimento',
                          '${_formatarData(nascimento, comHora: false)} (${_idade(nascimento)} anos)'),
                      if (m['cpf'] != null && (m['cpf'] as String).isNotEmpty)
                        _linha('CPF', m['cpf']),
                      if (domicilio != null)
                        _linha('Endereço',
                            '${domicilio['rua']}, ${domicilio['numero']} - ${domicilio['bairro']}'),
                      if (gestante || acamado)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              if (gestante)
                                const Chip(
                                  label: Text('Gestante'),
                                  backgroundColor: Color(0xFFFCE4EC),
                                ),
                              if (acamado)
                                const Chip(
                                  avatar: Icon(Icons.bed, size: 18),
                                  label: Text('Acamado'),
                                  backgroundColor: Color(0xFFEDE7F6),
                                ),
                            ],
                          ),
                        ),
                      if (comorbidades.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Comorbidades',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: comorbidades
                              .map((c) =>
                                  Chip(label: Text(comorbidadesLabels[c] ?? c)))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (m['anotacoes_agente'] != null &&
                  (m['anotacoes_agente'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFFFFDE7),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.sticky_note_2_outlined,
                                size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Anotações do agente',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(m['anotacoes_agente'],
                            style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
              if (familia?['observacoes'] != null &&
                  (familia['observacoes'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Observações da família',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(familia['observacoes'],
                            style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Histórico de visitas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text(
                'Inclui visitas gerais à família e acompanhamentos individuais.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _visitasFuture,
                builder: (context, snapVisitas) {
                  if (!snapVisitas.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final visitas = snapVisitas.data!;
                  if (visitas.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nenhuma visita registrada.',
                          style: TextStyle(color: Colors.black54)),
                    );
                  }

                  return Column(
                    children: visitas.map((v) {
                      final individual = v['morador_id'] != null;
                      final data = DateTime.parse(v['data_visita']);
                      final resultado =
                          (v['resultado'] as String?) ?? 'realizada';
                      final obs = v['observacoes'] as String?;
                      final registrador = v['registrado_por']?['nome'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(iconeResultado(resultado),
                                      color: corResultado(resultado), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatarData(data),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${individual ? "Visita individual" : "Visita geral da família"}'
                                ' • ${rotulosResultado[resultado] ?? resultado}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                              if (registrador != null)
                                Text('Registrada por $registrador',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54)),
                              if (obs != null && obs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(obs, style: const TextStyle(fontSize: 15)),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _linha(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(rotulo,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}