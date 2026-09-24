import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/domicilio.dart';
import '../models/familia.dart';
import '../models/morador.dart';
import '../models/visita.dart';
import '../database/familia_dao.dart';
import '../database/morador_dao.dart';
import '../database/visita_dao.dart';
import '../widgets/dialogo_visita.dart';
import 'tela_cadastro_familia.dart';
import 'tela_cadastro_morador.dart';
import 'tela_ficha_morador.dart';

String _formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.year} às ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

class TelaDetalheDomicilio extends StatefulWidget {
  final Domicilio domicilio;

  const TelaDetalheDomicilio({super.key, required this.domicilio});

  @override
  State<TelaDetalheDomicilio> createState() => _TelaDetalheDomicilioState();
}

class _TelaDetalheDomicilioState extends State<TelaDetalheDomicilio> {
  final _familiaDao = FamiliaDao();
  final _visitaDao = VisitaDao();
  late Future<List<Familia>> _familiasFuture;
  late Future<List<Visita>> _tentativasFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _familiasFuture = _familiaDao.listarPorDomicilio(widget.domicilio.id);
    _tentativasFuture =
        _visitaDao.listarTentativasDoDomicilio(widget.domicilio.id);
  }

  Future<void> _adicionarFamilia() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroFamilia(domicilioId: widget.domicilio.id),
      ),
    );
    setState(_carregar);
  }

  Future<void> _editarFamilia(Familia familia) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroFamilia(
          domicilioId: widget.domicilio.id,
          familiaParaEditar: familia,
        ),
      ),
    );
    setState(_carregar);
  }

  Future<void> _excluirFamilia(Familia familia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir família'),
        content: const Text(
          'Isso vai remover essa família e todos os moradores cadastrados nela. '
          'Deseja continuar?',
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

    if (confirmar == true) {
      await _familiaDao.inativar(familia.id);
      setState(_carregar);
    }
  }

  Future<void> _registrarTentativa() async {
    final dados = await mostrarDialogoVisita(
      context,
      titulo: 'Registrar tentativa de visita',
      subtitulo: 'Esta casa ainda não tem família cadastrada.',
      permitirRealizada: false,
      resultadoInicial: 'ausente',
    );
    if (dados == null) return;

    await _visitaDao.inserir(Visita(
      id: const Uuid().v4(),
      domicilioId: widget.domicilio.id,
      dataVisita: DateTime.now(),
      resultado: dados.resultado,
      observacoes: dados.observacoes,
    ));

    if (!mounted) return;
    setState(_carregar);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tentativa de visita registrada!')),
    );
  }

  Future<void> _excluirTentativa(Visita visita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir tentativa'),
        content: const Text('Deseja excluir este registro?'),
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
    if (mounted) setState(_carregar);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.domicilio;

    return Scaffold(
      appBar: AppBar(title: Text('${d.rua}, ${d.numero}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarFamilia,
        icon: const Icon(Icons.group_add),
        label: const Text('Nova família'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${d.bairro}${d.complemento != null ? ' • ${d.complemento}' : ''}',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Familia>>(
              future: _familiasFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final familias = snapshot.data!;

                if (familias.isEmpty) return _secaoNaoCadastrada();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: familias.length,
                  itemBuilder: (context, index) {
                    final familia = familias[index];
                    return _CartaoFamilia(
                      key: ValueKey(familia.id),
                      familia: familia,
                      onEditarFamilia: () => _editarFamilia(familia),
                      onExcluirFamilia: () => _excluirFamilia(familia),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoNaoCadastrada() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      children: [
        Card(
          color: const Color(0xFFF3E5F5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.house_outlined, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Casa não cadastrada',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nenhuma família cadastrada ainda. Registre as tentativas de '
                  'visita e, quando encontrar os moradores, toque em '
                  '"Nova família".',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _registrarTentativa,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Registrar tentativa de visita'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Tentativas registradas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<List<Visita>>(
          future: _tentativasFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final tentativas = snapshot.data!;
            if (tentativas.isEmpty) {
              return const Text('Nenhuma tentativa registrada ainda.',
                  style: TextStyle(color: Colors.black54));
            }
            return Column(
              children: tentativas.map((v) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(iconeResultado(v.resultado),
                        color: corResultado(v.resultado)),
                    title: Text(_formatarData(v.dataVisita)),
                    subtitle: Text(
                      '${rotulosResultado[v.resultado]}'
                      '${v.observacoes != null ? '\n${v.observacoes}' : ''}',
                    ),
                    isThreeLine: v.observacoes != null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Excluir',
                      onPressed: () => _excluirTentativa(v),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CartaoFamilia extends StatefulWidget {
  final Familia familia;
  final VoidCallback onEditarFamilia;
  final VoidCallback onExcluirFamilia;

  const _CartaoFamilia({
    super.key,
    required this.familia,
    required this.onEditarFamilia,
    required this.onExcluirFamilia,
  });

  @override
  State<_CartaoFamilia> createState() => _CartaoFamiliaState();
}

class _CartaoFamiliaState extends State<_CartaoFamilia> {
  final _moradorDao = MoradorDao();
  final _visitaDao = VisitaDao();
  late Future<List<Morador>> _moradoresFuture;
  late Future<Visita?> _ultimaVisitaFuture;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  void _carregarTudo() {
    _moradoresFuture = _moradorDao.listarPorFamilia(widget.familia.id);
    _ultimaVisitaFuture = _visitaDao.ultimaVisitaFamilia(widget.familia.id);
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

  Future<void> _registrarVisitaFamilia() async {
    final dados = await mostrarDialogoVisita(
      context,
      titulo: 'Registrar visita à família',
    );
    if (dados == null) return;

    await _visitaDao.inserir(Visita(
      id: const Uuid().v4(),
      domicilioId: widget.familia.domicilioId,
      familiaId: widget.familia.id,
      dataVisita: DateTime.now(),
      resultado: dados.resultado,
      observacoes: dados.observacoes,
    ));

    if (!mounted) return;
    setState(_carregarTudo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visita à família registrada!')),
    );
  }

  Future<void> _adicionarMorador() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TelaCadastroMorador(familiaExistenteId: widget.familia.id),
      ),
    );
    setState(_carregarTudo);
  }

  Future<void> _abrirFicha(Morador m) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaFichaMorador(morador: m)),
    );
    setState(_carregarTudo);
  }

  Future<void> _excluirMorador(Morador morador) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir morador'),
        content: Text('Deseja excluir o cadastro de "${morador.nome}"?'),
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

    if (confirmar == true) {
      await _moradorDao.inativar(morador.id);
      setState(_carregarTudo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: const Icon(Icons.family_restroom, color: Colors.teal),
        title: const Text('Família',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: FutureBuilder<Visita?>(
          future: _ultimaVisitaFuture,
          builder: (context, snapshot) {
            final linhas = <String>[];
            final obs = widget.familia.observacoes;
            if (obs != null && obs.isNotEmpty) linhas.add(obs);

            if (snapshot.connectionState == ConnectionState.done) {
              final v = snapshot.data;
              if (v == null) {
                linhas.add('Nenhuma visita geral registrada ainda');
              } else {
                final dias = DateTime.now().difference(v.dataVisita).inDays;
                linhas.add('Última visita há $dias dia(s) • '
                    '${rotulosResultado[v.resultado]}');
              }
            }
            return Text(linhas.join('\n'));
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_task, color: Colors.teal),
              tooltip: 'Registrar visita à família',
              onPressed: _registrarVisitaFamilia,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.black54),
              tooltip: 'Editar família',
              onPressed: widget.onEditarFamilia,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Excluir família',
              onPressed: widget.onExcluirFamilia,
            ),
          ],
        ),
        children: [
          FutureBuilder<List<Morador>>(
            future: _moradoresFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }

              final moradores = snapshot.data!;

              return Column(
                children: [
                  if (moradores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhum morador cadastrado nesta família.'),
                    )
                  else
                    ...moradores.map((m) {
                      final idade = _calcularIdade(m.dataNascimento);
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(m.nome),
                        subtitle: Text(
                          '$idade anos'
                          '${m.gestante ? ' • Gestante' : ''}'
                          '${m.acamado ? ' • Acamado' : ''}'
                          '${m.comorbidades.isNotEmpty ? ' • ${m.comorbidades.join(', ')}' : ''}',
                        ),
                        onTap: () => _abrirFicha(m),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Excluir morador',
                          onPressed: () => _excluirMorador(m),
                        ),
                      );
                    }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _adicionarMorador,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Adicionar morador'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}