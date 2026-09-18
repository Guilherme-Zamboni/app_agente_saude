import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'tela_gestao_agentes.dart';
import 'tela_gestao_territorios.dart';
import 'tela_selecionar_microarea.dart';

class TelaPainelCoordenador extends StatelessWidget {
  final PerfilUsuario perfil;

  const TelaPainelCoordenador({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da coordenação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => AuthService.sair(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.teal[50],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 40, color: Colors.teal),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(perfil.nome,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Coordenação',
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _opcao(
            context,
            icone: Icons.travel_explore,
            titulo: 'Consultar microáreas',
            descricao: 'Ver o mapa e os moradores de cada agente',
            destino: const TelaSelecionarMicroarea(),
          ),
          _opcao(
            context,
            icone: Icons.people_outline,
            titulo: 'Agentes',
            descricao: 'Cadastrar e gerenciar os agentes de saúde',
            destino: const TelaGestaoAgentes(),
          ),
          _opcao(
            context,
            icone: Icons.map_outlined,
            titulo: 'Microáreas',
            descricao: 'Criar territórios e vincular aos agentes',
            destino: const TelaGestaoTerritorios(),
          ),
        ],
      ),
    );
  }

  Widget _opcao(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    required String descricao,
    required Widget destino,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icone, size: 32, color: Colors.teal),
        title: Text(titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text(descricao),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destino),
        ),
      ),
    );
  }
}