import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class TelaGestaoAgentes extends StatefulWidget {
  const TelaGestaoAgentes({super.key});

  @override
  State<TelaGestaoAgentes> createState() => _TelaGestaoAgentesState();
}

class _TelaGestaoAgentesState extends State<TelaGestaoAgentes> {
  late Future<List<Map<String, dynamic>>> _agentesFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _agentesFuture = AdminService.listarAgentes();
  }

  Future<void> _novoAgente() async {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool salvando = false;
    String? erro;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Novo agente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome completo'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                      if (!v.contains('@')) return 'E-mail inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: senhaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Senha inicial',
                      helperText: 'Mínimo 6 caracteres',
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  if (erro != null) ...[
                    const SizedBox(height: 12),
                    Text(erro!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() {
                        salvando = true;
                        erro = null;
                      });
                      try {
                        await AdminService.criarAgente(
                          email: emailCtrl.text.trim(),
                          senha: senhaCtrl.text,
                          nome: nomeCtrl.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialog(() {
                          salvando = false;
                          erro = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: salvando
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    setState(_carregar);
  }

  Future<void> _editarAgente(Map<String, dynamic> agente) async {
    final nomeCtrl = TextEditingController(text: agente['nome']);
    bool ativo = agente['ativo'] ?? true;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Editar agente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: Text(ativo
                    ? 'Pode acessar o aplicativo'
                    : 'Acesso bloqueado'),
                value: ativo,
                onChanged: (v) => setDialog(() => ativo = v),
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

    if (salvou == true) {
      await AdminService.atualizarAgente(
        id: agente['id'],
        nome: nomeCtrl.text.trim(),
        ativo: ativo,
      );
      setState(_carregar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoAgente,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo agente'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _agentesFuture,
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

          final agentes = snapshot.data!;

          if (agentes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum agente cadastrado ainda.\n'
                  'Toque em "Novo agente" para começar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: agentes.length,
            itemBuilder: (context, index) {
              final a = agentes[index];
              final ativo = a['ativo'] ?? true;
              final territorios = a['territorio'] as List?;
              final nomeTerritorio = (territorios != null && territorios.isNotEmpty)
                  ? territorios.first['nome']
                  : null;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ativo ? Colors.teal : Colors.grey,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(a['nome'],
                    style: TextStyle(
                      fontSize: 17,
                      color: ativo ? null : Colors.grey,
                    )),
                subtitle: Text(
                  nomeTerritorio != null
                      ? 'Microárea: $nomeTerritorio'
                      : 'Sem microárea vinculada',
                  style: TextStyle(
                    color: nomeTerritorio != null ? null : Colors.orange[800],
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editarAgente(a),
                ),
              );
            },
          );
        },
      ),
    );
  }
}