import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/admin_service.dart';
import '../services/mapa_service.dart';

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

  Future<void> _enviarMapa(Map<String, dynamic> territorio) async {
    final escolha = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Imagem do mapa',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (escolha == null) return;

    final selecionada =
        await ImagePicker().pickImage(source: escolha, imageQuality: 85);
    if (selecionada == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Enviando mapa...')),
          ],
        ),
      ),
    );

    try {
      final resultado = await MapaService.enviar(
        territorioId: territorio['id'],
        arquivo: File(selecionada.path),
      );

      await AdminService.atualizarMapa(
        id: territorio['id'],
        url: resultado['url'],
        proporcao: resultado['proporcao'],
      );

      // se já havia um mapa, limpa o cache para o app baixar o novo
      final anterior = territorio['imagem_mapa'] as String?;
      if (anterior != null) await MapaService.limparCache(anterior);

      if (!mounted) return;
      Navigator.pop(context); // fecha o "enviando"
      setState(_carregar);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapa atualizado!')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar: $e')),
      );
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
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: territorios.length,
            itemBuilder: (context, index) {
              final t = territorios[index];
              final agente = t['agente'];
              final temMapa = (t['imagem_mapa'] as String?)?.isNotEmpty ?? false;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.map, color: Colors.white),
                      ),
                      title:
                          Text(t['nome'], style: const TextStyle(fontSize: 17)),
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
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        temMapa ? Icons.image : Icons.image_not_supported_outlined,
                        color: temMapa ? Colors.teal : Colors.orange[800],
                      ),
                      title: Text(
                        temMapa
                            ? 'Mapa definido'
                            : 'Sem mapa — usando imagem padrão',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: TextButton.icon(
                        onPressed: () => _enviarMapa(t),
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(temMapa ? 'Trocar' : 'Enviar'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}