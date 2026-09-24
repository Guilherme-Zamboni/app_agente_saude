import 'package:flutter/material.dart';
import '../services/estatisticas_api_service.dart';
/// import 'tela_cadastro_morador.dart' show comorbidadesLabels;

class TelaEstatisticasConsolidadas extends StatefulWidget {
  const TelaEstatisticasConsolidadas({super.key});

  @override
  State<TelaEstatisticasConsolidadas> createState() =>
      _TelaEstatisticasConsolidadasState();
}

class _Dados {
  final Map<String, dynamic> geral;
  final Map<String, dynamic> visitasMes;

  _Dados(this.geral, this.visitasMes);
}

class _TelaEstatisticasConsolidadasState
    extends State<TelaEstatisticasConsolidadas> {
  late Future<_Dados> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_Dados> _carregar() async {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, 1);
    final fim = DateTime(
        agora.month == 12 ? agora.year + 1 : agora.year,
        agora.month == 12 ? 1 : agora.month + 1,
        1);

    final geral = await EstatisticasApiService.consolidadas();
    final visitas =
        await EstatisticasApiService.visitas(inicio: inicio, fim: fim);

    return _Dados(geral, visitas);
  }

  int _n(dynamic valor) => (valor as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => setState(() => _future = _carregar()),
          ),
        ],
      ),
      body: FutureBuilder<_Dados>(
        future: _future,
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

          final geral = snapshot.data!.geral;
          final visitas = snapshot.data!.visitasMes;

          final domicilios =
              Map<String, dynamic>.from(geral['domicilios'] as Map);
          final moradores =
              Map<String, dynamic>.from(geral['moradores'] as Map);
          final porResultado =
              Map<String, dynamic>.from(visitas['por_resultado'] as Map);
          final microareas =
              List<Map<String, dynamic>>.from(geral['por_microarea'] as List);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _cartaoGrande('${_n(geral['microareas'])}',
                        'microáreas', Icons.map_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cartaoGrande('${_n(domicilios['total'])}',
                        'domicílios', Icons.home_work_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cartaoGrande('${_n(moradores['total'])}',
                        'moradores', Icons.groups_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _secao('Visitas deste mês', [
                _linha('Total de visitas', _n(visitas['total_visitas']),
                    destaque: true),
                _linha('Atendidas', _n(porResultado['realizada'])),
                _linha('Moradores ausentes', _n(porResultado['ausente'])),
                _linha('Recusadas', _n(porResultado['recusada'])),
                _linha('Domicílios visitados',
                    _n(visitas['domicilios_visitados'])),
              ]),
              _secao('Situação das áreas', [
                _linha('Casas não cadastradas',
                    _n(domicilios['nao_cadastrados'])),
                _linha('Pendentes de visita (30 dias)',
                    _n(domicilios['pendentes_visita'])),
              ]),
              _secao('População acompanhada', [
                _linha('Gestantes', _n(moradores['gestantes'])),
                _linha('Menores de 2 anos',
                    _n(moradores['criancas_menores_2_anos'])),
                _linha('Idosos (60+)', _n(moradores['idosos_60_mais'])),
                _linha('Acamados', _n(moradores['acamados'])),
              ]),
              const SizedBox(height: 4),
              const Text('Por microárea',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...microareas.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.map, color: Colors.white, size: 20),
                      ),
                      title: Text(m['nome'] ?? '-'),
                      subtitle: Text(
                        '${m['agente'] ?? 'Sem agente'} • '
                        '${_n(m['domicilios'])} domicílios • '
                        '${_n(m['moradores'])} moradores',
                      ),
                      trailing: _n(m['pendentes_visita']) > 0
                          ? Chip(
                              label: Text('${_n(m['pendentes_visita'])}',
                                  style: const TextStyle(fontSize: 12)),
                              avatar: const Icon(Icons.warning_amber_rounded,
                                  size: 16),
                              backgroundColor: const Color(0xFFFFF3E0),
                              visualDensity: VisualDensity.compact,
                            )
                          : const Icon(Icons.check_circle_outline,
                              color: Colors.green),
                    ),
                  )),
              const SizedBox(height: 8),
              const Text(
                'Os números pendentes indicam domicílios sem visita nos '
                'últimos 30 dias.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cartaoGrande(String valor, String rotulo, IconData icone) {
    return Card(
      color: Colors.teal[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icone, color: Colors.teal, size: 24),
            const SizedBox(height: 6),
            Text(valor,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            Text(rotulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _secao(String titulo, List<Widget> linhas) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...linhas,
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, int valor, {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(rotulo,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: destaque ? FontWeight.bold : null)),
          ),
          Text('$valor',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: destaque ? Colors.teal : null)),
        ],
      ),
    );
  }
}