import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import 'tela_mapa_consulta.dart';

class TelaSelecionarMicroarea extends StatefulWidget {
  const TelaSelecionarMicroarea({super.key});

  @override
  State<TelaSelecionarMicroarea> createState() =>
      _TelaSelecionarMicroareaState();
}

class _TelaSelecionarMicroareaState extends State<TelaSelecionarMicroarea> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.listarTerritorios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultar microáreas')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
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
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TelaMapaConsulta(
                      territorioId: t['id'],
                      nomeTerritorio: t['nome'],
                      nomeAgente: agente?['nome'],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}