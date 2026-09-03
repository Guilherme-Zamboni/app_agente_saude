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
    final criancas = await _moradorDao.contarCriancasAte4Anos();
    final idosos = await _moradorDao.contarIdosos();

    final comorbidades = <String, int>{};
    for (final c in comorbidadesDisponiveis) {
      comorbidades[c] = await _moradorDao.contarPorComorbidade(c);
    }

    return _DadosEstatisticas(
      total: total,
      gestantes: gestantes,
      criancas: criancas,
      idosos: idosos,
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Card com o total geral ---
              Card(
                color: Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('${dados.total}',
                          style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold, color: Colors.teal)),
                      const Text('moradores cadastrados na área',
                          style: TextStyle(fontSize: 15, color: Colors.black54)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Grade com os grupos prioritários ---
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  _cartaoNumero('Gestantes', dados.gestantes, Icons.pregnant_woman, Colors.pink),
                  _cartaoNumero('0-4 anos', dados.criancas, Icons.child_care, Colors.blue),
                  _cartaoNumero('Idosos 60+', dados.idosos, Icons.elderly, Colors.orange),
                ],
              ),

              const SizedBox(height: 24),

              const Text('Comorbidades',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // --- Gráfico de barras das comorbidades ---
              // --- Gráfico de barras das comorbidades ---
              SizedBox(
                height: 260,
                child: dados.comorbidades.values.every((v) => v == 0)
                    ? const Center(
                        child: Text('Nenhuma comorbidade registrada ainda.',
                            style: TextStyle(color: Colors.black45)),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (dados.comorbidades.values
                                          .fold<int>(0, (a, b) => a > b ? a : b) +
                                      1)
                                  .toDouble() +
                              0.5,
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
                                  final label =
                                      comorbidadesLabels[chaves[index]] ?? chaves[index];
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
                          gridData: FlGridData(
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
                            final index = entry.key;
                            final valor = entry.value.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: valor.toDouble(),
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

              // --- Lista com os percentuais exatos ---
              const Text('Percentuais',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _linhaPercentual('Gestantes', dados.gestantes, dados.total),
                    _linhaPercentual('Crianças de 0 a 4 anos', dados.criancas, dados.total),
                    _linhaPercentual('Idosos (60+)', dados.idosos, dados.total),
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
            Icon(icone, color: cor, size: 26),
            const SizedBox(height: 6),
            Text('$valor',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
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
  final Map<String, int> comorbidades;

  _DadosEstatisticas({
    required this.total,
    required this.gestantes,
    required this.criancas,
    required this.idosos,
    required this.comorbidades,
  });
}