import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/morador_dao.dart';
import 'tela_cadastro_morador.dart' show comorbidadesDisponiveis, comorbidadesLabels;

class TelaEstatisticas extends StatefulWidget {
  const TelaEstatisticas({super.key});

  @override
  State<TelaEstatisticas> createState() => _TelaEstatisticasState();
}

class _TelaEstatisticasState extends State<TelaEstatisticas> {
  final _moradorDao = MoradorDao();
  late Future<_DadosEstatisticas> _dadosFuture;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _dadosFuture = _carregarDados();
  }

  Future<_DadosEstatisticas> _carregarDados() async {
    final total = await _moradorDao.contarTotal();
    final gestantes = await _moradorDao.contarGestantes();
    final criancas = await _moradorDao.contarCriancasMenores2Anos();
    final idosos = await _moradorDao.contarIdosos();
    final acamados = await _moradorDao.contarAcamados();

    final comorbidades = <String, int>{};
    for (final c in comorbidadesDisponiveis) {
      comorbidades[c] = await _moradorDao.contarPorComorbidade(c);
    }

    return _DadosEstatisticas(
      total: total,
      gestantes: gestantes,
      criancas: criancas,
      idosos: idosos,
      acamados: acamados,
      comorbidades: comorbidades,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas da área'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => setState(_carregar),
          ),
        ],
      ),
      body: FutureBuilder<_DadosEstatisticas>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final dados = snapshot.data!;

          if (dados.total == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum morador cadastrado ainda nesta área.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }

          final maiorComorbidade = dados.comorbidades.values
              .fold<int>(0, (a, b) => a > b ? a : b);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('${dados.total}',
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                      const Text('moradores cadastrados na área',
                          style: TextStyle(fontSize: 15, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _cartaoNumero('Gestantes', dados.gestantes,
                      Icons.pregnant_woman, Colors.pink),
                  _cartaoNumero('Menores de 2 anos', dados.criancas,
                      Icons.child_care, Colors.blue),
                  _cartaoNumero(
                      'Idosos 60+', dados.idosos, Icons.elderly, Colors.orange),
                  _cartaoNumero(
                      'Acamados', dados.acamados, Icons.bed, Colors.purple),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Comorbidades',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: maiorComorbidade == 0
                    ? const Center(
                        child: Text('Nenhuma comorbidade registrada ainda.',
                            style: TextStyle(color: Colors.black45)),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maiorComorbidade + 1.5,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value != value.roundToDouble()) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 56,
                                getTitlesWidget: (value, meta) {
                                  final chaves = dados.comorbidades.keys.toList();
                                  final index = value.toInt();
                                  if (index < 0 || index >= chaves.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = comorbidadesLabels[chaves[index]] ??
                                      chaves[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: 60,
                                      child: Text(
                                        label,
                                        style: const TextStyle(fontSize: 10),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                          ),
                          groupsSpace: 20,
                          barGroups: dados.comorbidades.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value.toDouble(),
                                  color: Colors.teal,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              const Text('Percentuais',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _linhaPercentual('Gestantes', dados.gestantes, dados.total),
                    _linhaPercentual(
                        'Crianças menores de 2 anos', dados.criancas, dados.total),
                    _linhaPercentual('Idosos (60+)', dados.idosos, dados.total),
                    _linhaPercentual('Acamados', dados.acamados, dados.total),
                    for (final entry in dados.comorbidades.entries)
                      _linhaPercentual(
                        comorbidadesLabels[entry.key] ?? entry.key,
                        entry.value,
                        dados.total,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cartaoNumero(String label, int valor, IconData icone, Color cor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: cor, size: 28),
            const SizedBox(height: 4),
            Text('$valor',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaPercentual(String label, int valor, int total) {
    final percentual = total == 0 ? 0.0 : (valor / total) * 100;
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        '$valor (${percentual.toStringAsFixed(1)}%)',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DadosEstatisticas {
  final int total;
  final int gestantes;
  final int criancas;
  final int idosos;
  final int acamados;
  final Map<String, int> comorbidades;

  _DadosEstatisticas({
    required this.total,
    required this.gestantes,
    required this.criancas,
    required this.idosos,
    required this.acamados,
    required this.comorbidades,
  });
}