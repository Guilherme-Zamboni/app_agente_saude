import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/domicilio.dart';
import '../models/familia.dart';
import '../models/morador.dart';
import '../models/visita.dart';
import '../database/familia_dao.dart';
import '../database/morador_dao.dart';
import '../database/visita_dao.dart';
import 'tela_cadastro_familia.dart';
import 'tela_cadastro_morador.dart';
import 'tela_ficha_morador.dart';

class TelaDetalheDomicilio extends StatefulWidget {
  final Domicilio domicilio;

  const TelaDetalheDomicilio({super.key, required this.domicilio});

  @override
  State<TelaDetalheDomicilio> createState() => _TelaDetalheDomicilioState();
}

class _TelaDetalheDomicilioState extends State<TelaDetalheDomicilio> {
  final _familiaDao = FamiliaDao();
  late Future<List<Familia>> _familiasFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _familiasFuture = _familiaDao.listarPorDomicilio(widget.domicilio.id);
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

  @override
  Widget build(BuildContext context) {
    final d = widget.domicilio;

    return Scaffold(
      appBar: AppBar(
        title: Text('${d.rua}, ${d.numero}'),
      ),
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

                if (familias.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma família cadastrada neste domicílio ainda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
  late Future<DateTime?> _ultimaVisitaFamiliaFuture;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  void _carregarTudo() {
    _moradoresFuture = _moradorDao.listarPorFamilia(widget.familia.id);
    _ultimaVisitaFamiliaFuture =
        _visitaDao.dataUltimaVisitaFamilia(widget.familia.id);
  }

  void _carregarMoradores() {
    _moradoresFuture = _moradorDao.listarPorFamilia(widget.familia.id);
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
    final observacoesController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar visita à família'),
        content: TextField(
          controller: observacoesController,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            labelText: 'Observações (opcional)',
            border: OutlineInputBorder(),
          ),
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
      familiaId: widget.familia.id,
      moradorId: null,
      dataVisita: DateTime.now(),
      observacoes: observacoesController.text.trim().isEmpty
          ? null
          : observacoesController.text.trim(),
    );

    await _visitaDao.inserir(visita);

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
        builder: (_) => TelaCadastroMorador(
          familiaExistenteId: widget.familia.id,
        ),
      ),
    );
    setState(_carregarMoradores);
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
        subtitle: FutureBuilder<DateTime?>(
          future: _ultimaVisitaFamiliaFuture,
          builder: (context, snapshot) {
            final texto = widget.familia.observacoes != null
                ? '${widget.familia.observacoes}\n'
                : '';
            if (!snapshot.hasData || snapshot.data == null) {
              return Text('$texto Nenhuma visita geral registrada ainda');
            }
            final dias = DateTime.now().difference(snapshot.data!).inDays;
            return Text('$texto Última visita à família há $dias dia(s)');
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