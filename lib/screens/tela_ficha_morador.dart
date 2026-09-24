import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/morador.dart';
import '../models/visita.dart';
import '../database/familia_dao.dart';
import '../database/morador_dao.dart';
import '../database/visita_dao.dart';
import '../widgets/dialogo_visita.dart';
import 'tela_cadastro_morador.dart';

const int _diasLimiteVisita = 30;

class TelaFichaMorador extends StatefulWidget {
  final Morador morador;

  const TelaFichaMorador({super.key, required this.morador});

  @override
  State<TelaFichaMorador> createState() => _TelaFichaMoradorState();
}

class _TelaFichaMoradorState extends State<TelaFichaMorador> {
  final _visitaDao = VisitaDao();
  final _moradorDao = MoradorDao();
  final _familiaDao = FamiliaDao();

  late Morador _morador;
  late Future<List<Visita>> _visitasFuture;

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

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year} às '
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
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
    final dados = await mostrarDialogoVisita(
      context,
      titulo: 'Registrar visita individual',
      subtitulo: 'Acompanhamento específico deste morador, '
          'fora da visita geral à família.',
    );
    if (dados == null) return;

    final familia = await _familiaDao.buscarPorId(_morador.familiaId);
    if (familia == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Família do morador não encontrada')),
      );
      return;
    }

    await _visitaDao.inserir(Visita(
      id: const Uuid().v4(),
      domicilioId: familia.domicilioId,
      familiaId: _morador.familiaId,
      moradorId: _morador.id,
      dataVisita: DateTime.now(),
      resultado: dados.resultado,
      observacoes: dados.observacoes,
    ));

    if (!mounted) return;
    setState(_carregar);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visita individual registrada!')),
    );
  }

  Future<void> _editarVisita(Visita visita) async {
    final dados = await mostrarDialogoVisita(
      context,
      titulo: visita.individual
          ? 'Editar visita individual'
          : 'Editar visita da família',
      resultadoInicial: visita.resultado,
      observacoesIniciais: visita.observacoes,
      dataInicial: visita.dataVisita,
      permitirEditarData: true,
    );
    if (dados == null) return;

    await _visitaDao.atualizar(Visita(
      id: visita.id,
      domicilioId: visita.domicilioId,
      familiaId: visita.familiaId,
      moradorId: visita.moradorId,
      dataVisita: dados.data,
      resultado: dados.resultado,
      observacoes: dados.observacoes,
    ));

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

    await _visitaDao.inativar(visita.id);

    if (!mounted) return;
    setState(_carregar);
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
      body: FutureBuilder<List<Visita>>(
        future: _visitasFuture,
        builder: (context, snapshot) {
          final visitas = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
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
                      if (_morador.cpf != null)
                        _linhaInfo('CPF', _morador.cpf!),
                      if (_morador.gestante || _morador.acamado)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              if (_morador.gestante)
                                const Chip(
                                  label: Text('Gestante'),
                                  backgroundColor: Color(0xFFFCE4EC),
                                ),
                              if (_morador.acamado)
                                const Chip(
                                  avatar: Icon(Icons.bed, size: 18),
                                  label: Text('Acamado'),
                                  backgroundColor: Color(0xFFEDE7F6),
                                ),
                            ],
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
                              .map((c) => Chip(
                                    label: Text(comorbidadesLabels[c] ?? c),
                                  ))
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
              if (visitas != null) _indicadorUltimaVisita(visitas),
              const SizedBox(height: 16),
              const Text('Histórico de visitas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text(
                'Inclui visitas gerais à família e acompanhamentos individuais '
                'deste morador.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              if (visitas == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visitas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nenhuma visita registrada ainda.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                ...visitas.map(_itemVisita),
            ],
          );
        },
      ),
    );
  }

  Widget _indicadorUltimaVisita(List<Visita> visitas) {
    String texto;
    Color fundo;
    Color corIcone;
    IconData icone;

    if (visitas.isEmpty) {
      texto = 'Nenhuma visita registrada ainda (família ou individual)';
      fundo = const Color(0xFFFFF3E0);
      corIcone = Colors.orange.shade800;
      icone = Icons.warning_amber_rounded;
    } else {
      final ultima = visitas.first;
      final dias = DateTime.now().difference(ultima.dataVisita).inDays;

      if (dias > _diasLimiteVisita) {
        texto = 'Última visita há $dias dia(s) — visita em atraso';
        fundo = const Color(0xFFFFF3E0);
        corIcone = Colors.orange.shade800;
        icone = Icons.warning_amber_rounded;
      } else if (ultima.resultado == 'ausente') {
        texto = 'Última visita há $dias dia(s) — moradores ausentes';
        fundo = const Color(0xFFFFF8E1);
        corIcone = corResultado('ausente');
        icone = iconeResultado('ausente');
      } else if (ultima.resultado == 'recusada') {
        texto = 'Última visita há $dias dia(s) — visita recusada';
        fundo = const Color(0xFFFFEBEE);
        corIcone = corResultado('recusada');
        icone = iconeResultado('recusada');
      } else {
        texto = 'Última visita há $dias dia(s)';
        fundo = const Color(0xFFE8F5E9);
        corIcone = corResultado('realizada');
        icone = iconeResultado('realizada');
      }
    }

    return Card(
      color: fundo,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icone, color: corIcone),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _itemVisita(Visita v) {
    final temObs = v.observacoes != null && v.observacoes!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(iconeResultado(v.resultado),
            color: corResultado(v.resultado)),
        title: Text(_formatarData(v.dataVisita)),
        subtitle: Text(
          '${v.individual ? "Individual" : "Geral da família"} • '
          '${rotulosResultado[v.resultado]}'
          '${temObs ? "\n${v.observacoes}" : ""}',
        ),
        isThreeLine: temObs,
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}