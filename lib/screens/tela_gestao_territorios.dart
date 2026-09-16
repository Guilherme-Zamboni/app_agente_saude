import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class TelaGestaoTerritorios extends StatefulWidget {
  const TelaGestaoTerritorios({super.key});

  @override
  State<TelaGestaoTerritorios> createState() => _TelaGestaoTerritoriosState();
}

class _TelaGestaoTerritoriosState extends State<TelaGestaoTerritorios> {
  late Future<List<Map<String, dynamic>>> _territoriosFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _territoriosFuture = AdminService.listarTerritorios();
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? territorio}) async {
    final editando = territorio != null;
    final nomeCtrl = TextEditingController(text: territorio?['nome'] ?? '');
    String? agenteSelecionado = territorio?['agente_id'];

    final agentes = await AdminService.listarAgentes();
    if (!mounted) return;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(editando ? 'Editar microárea' : 'Nova microárea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome da microárea',
                  hintText: 'Ex: Jardim das Flores',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: agenteSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Agente responsável',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem agente vinculado'),
                  ),
                  ...agentes.map((a) => DropdownMenuItem<String?>(
                        value: a['id'] as String,
                        child: Text(a['nome']),
                      )),
                ],
                onChanged: (v) => setDialog(() => agenteSelecionado = v),
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
        ),
      ),
    );

    if (salvou == true && nomeCtrl.text.trim().isNotEmpty) {
      if (editando) {
        await AdminService.atualizarTerritorio(
          id: territorio['id'],
          nome: nomeCtrl.text.trim(),
          agenteId: agenteSelecionado,
        );
      } else {
        await AdminService.criarTerritorio(
          nome: nomeCtrl.text.trim(),
          agenteId: agenteSelecionado,
        );
      }
      setState(_carregar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Microáreas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nova microárea'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _territoriosFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro ao carregar: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final territorios = snapshot.data!;

          if (territorios.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhuma microárea cadastrada ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: territorios.length,
            itemBuilder: (context, index) {
              final t = territorios[index];
              final agente = t['agente'];

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.map, color: Colors.white),
                ),
                title: Text(t['nome'], style: const TextStyle(fontSize: 17)),
                subtitle: Text(
                  agente != null
                      ? 'Agente: ${agente['nome']}'
                      : 'Sem agente vinculado',
                  style: TextStyle(
                    color: agente != null ? null : Colors.orange[800],
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _abrirFormulario(territorio: t),
                ),
              );
            },
          );
        },
      ),
    );
  }
}