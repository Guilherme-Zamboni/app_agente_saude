import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/morador.dart';
import '../models/visita.dart';
import '../database/morador_dao.dart';
import '../database/visita_dao.dart';
import 'tela_cadastro_morador.dart';

class TelaFichaMorador extends StatefulWidget {
  final Morador morador;

  const TelaFichaMorador({super.key, required this.morador});

  @override
  State<TelaFichaMorador> createState() => _TelaFichaMoradorState();
}

class _TelaFichaMoradorState extends State<TelaFichaMorador> {
  final _visitaDao = VisitaDao();
  final _moradorDao = MoradorDao();

  late Morador _morador;
  late Future<List<Visita>> _visitasFuture;
  late Future<int?> _diasDesdeUltimaVisitaFuture;

  @override
  void initState() {
    super.initState();
    _morador = widget.morador;
    _carregar();
  }

  void _carregar() {
    _visitasFuture = _visitaDao.listarHistoricoDoMorador(
      moradorId: _morador.id,
      familiaId: _morador.familiaId,
    );
    _diasDesdeUltimaVisitaFuture = _visitaDao.diasDesdeUltimaVisitaMorador(
      moradorId: _morador.id,
      familiaId: _morador.familiaId,
    );
  }

  int _calcularIdade(DateTime nascimento) {
    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    return idade;
  }

  Future<void> _editarMorador() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroMorador(moradorParaEditar: _morador),
      ),
    );
    final atualizado = await _moradorDao.buscarPorId(_morador.id);
    if (atualizado != null && mounted) {
      setState(() {
        _morador = atualizado;
        _carregar();
      });
    }
  }

  Future<void> _registrarVisitaIndividual() async {
    final observacoesController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar visita individual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use isto para um acompanhamento específico deste morador, '
              'fora da visita geral feita à família.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: observacoesController,
              autofocus: true,
              maxLines: 4,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final visita = Visita(
      id: const Uuid().v4(),
      familiaId: _morador.familiaId,
      moradorId: _morador.id, // visita extra, específica deste morador
      dataVisita: DateTime.now(),
      observacoes: observacoesController.text.trim().isEmpty
          ? null
          : observacoesController.text.trim(),
    );

    await _visitaDao.inserir(visita);

    if (!mounted) return;
    setState(_carregar);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visita individual registrada!')),
    );
  }

  Future<void> _editarVisita(Visita visita) async {
    final observacoesController = TextEditingController(text: visita.observacoes ?? '');
    DateTime dataSelecionada = visita.dataVisita;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(visita.individual ? 'Editar visita individual' : 'Editar visita da família'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${dataSelecionada.day.toString().padLeft(2, '0')}/'
                    '${dataSelecionada.month.toString().padLeft(2, '0')}/'
                    '${dataSelecionada.year}',
                  ),
                  onTap: () async {
                    final novaData = await showDatePicker(
                      context: context,
                      initialDate: dataSelecionada,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (novaData != null) {
                      setDialogState(() {
                        dataSelecionada = DateTime(
                          novaData.year,
                          novaData.month,
                          novaData.day,
                          dataSelecionada.hour,
                          dataSelecionada.minute,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: observacoesController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (salvar != true) return;

    final visitaAtualizada = Visita(
      id: visita.id,
      familiaId: visita.familiaId,
      moradorId: visita.moradorId,
      dataVisita: dataSelecionada,
      observacoes: observacoesController.text.trim().isEmpty
          ? null
          : observacoesController.text.trim(),
    );

    await _visitaDao.atualizar(visitaAtualizada);

    if (!mounted) return;
    setState(_carregar);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visita atualizada!')),
    );
  }

  Future<void> _excluirVisita(Visita visita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir visita'),
        content: Text(
          visita.individual
              ? 'Deseja excluir este registro de visita individual?'
              : 'Deseja excluir este registro de visita geral da família? '
                'Isso afeta o indicador de todos os moradores dela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _visitaDao.deletar(visita.id);

    if (!mounted) return;
    setState(_carregar);
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year} às '
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final idade = _calcularIdade(_morador.dataNascimento);

    return Scaffold(
      appBar: AppBar(
        title: Text(_morador.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar cadastro',
            onPressed: _editarMorador,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrarVisitaIndividual,
        icon: const Icon(Icons.add_task),
        label: const Text('Visita individual'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _linhaInfo('Nome', _morador.nome),
                  _linhaInfo('Nome da mãe', _morador.nomeDaMae),
                  _linhaInfo('Idade', '$idade anos'),
                  if (_morador.cpf != null) _linhaInfo('CPF', _morador.cpf!),
                  if (_morador.gestante)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text('Gestante'),
                        backgroundColor: Color(0xFFFCE4EC),
                      ),
                    ),
                  if (_morador.comorbidades.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Comorbidades',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: _morador.comorbidades
                          .map((c) => Chip(label: Text(c)))
                          .toList(),
                    ),
                  ],
                  if (_morador.anotacoesAgente != null &&
                      _morador.anotacoesAgente!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Anotações',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_morador.anotacoesAgente!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          FutureBuilder<int?>(
            future: _diasDesdeUltimaVisitaFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }

              final dias = snapshot.data;
              final semVisita = dias == null;
              final atrasado = semVisita || dias > 30;

              return Card(
                color: atrasado ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        atrasado ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: atrasado ? Colors.orange[800] : Colors.green[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          semVisita
                              ? 'Nenhuma visita registrada ainda (família ou individual)'
                              : 'Última visita há $dias dia(s)',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          const Text('Histórico de visitas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text(
            'Inclui visitas gerais à família e acompanhamentos individuais deste morador.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),

          FutureBuilder<List<Visita>>(
            future: _visitasFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final visitas = snapshot.data!;

              if (visitas.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Nenhuma visita registrada ainda.',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              return Column(
                children: visitas.map((v) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        v.individual ? Icons.person_pin_circle : Icons.home_outlined,
                        color: Colors.teal,
                      ),
                      title: Text(_formatarData(v.dataVisita)),
                      subtitle: Text(
                        '${v.individual ? "Visita individual" : "Visita geral da família"}'
                        '${v.observacoes != null && v.observacoes!.isNotEmpty ? "\n${v.observacoes}" : ""}',
                      ),
                      isThreeLine: v.observacoes != null && v.observacoes!.isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Editar visita',
                            onPressed: () => _editarVisita(v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'Excluir visita',
                            onPressed: () => _excluirVisita(v),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _linhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(rotulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}