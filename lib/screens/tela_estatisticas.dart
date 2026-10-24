import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/morador_dao.dart';
import '../services/estatisticas_api_service.dart';
import 'tela_cadastro_morador.dart'
    show comorbidadesDisponiveis, comorbidadesLabels;

enum EscopoEstatisticas { minhaArea, todasAsAreas }

class TelaEstatisticas extends StatefulWidget {
  /// Microárea do agente: é a que vale para "Minha área".
  final String territorioId;
  final String? nomeTerritorio;

  const TelaEstatisticas({
    super.key,
    required this.territorioId,
    this.nomeTerritorio,
  });

  @override
  State<TelaEstatisticas> createState() => _TelaEstatisticasState();
}

class _TelaEstatisticasState extends State<TelaEstatisticas> {
  final _moradorDao = MoradorDao();
  EscopoEstatisticas _escopo = EscopoEstatisticas.minhaArea;
  late Future<_DadosEstatisticas> _dadosFuture;

  bool get _soMinhaArea => _escopo == EscopoEstatisticas.minhaArea;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _dadosFuture = _soMinhaArea ? _carregarLocal() : _carregarServidor();
  }

  /// Minha área: lê o banco do aparelho, filtrando pela microárea.
  /// Funciona sem internet.
  Future<_DadosEstatisticas> _carregarLocal() async {
    final id = widget.territorioId;

    final total = await _moradorDao.contarTotal(territorioId: id);
    final gestantes = await _moradorDao.contarGestantes(territorioId: id);
    final criancas =
        await _moradorDao.contarCriancasMenores2Anos(territorioId: id);
    final idosos = await _moradorDao.contarIdosos(territorioId: id);
    final acamados = await _moradorDao.contarAcamados(territorioId: id);

    final comorbidades = <String, int>{};
    for (final c in comorbidadesDisponiveis) {
      comorbidades[c] =
          await _moradorDao.contarPorComorbidade(c, territorioId: id);
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

  /// Todas as áreas: pede ao servidor os números somados.
  /// Precisa de internet. O servidor devolve só contagens.
  Future<_DadosEstatisticas> _carregarServidor() async {
    final json = await EstatisticasApiService.todasAsAreas()
        .timeout(const Duration(seconds: 15));

    int n(dynamic valor) => (valor as num?)?.toInt() ?? 0;

    final moradores = Map<String, dynamic>.from(json['moradores'] as Map);
    final porComorbidade =
        Map<String, dynamic>.from((json['comorbidades'] as Map?) ?? {});

    final comorbidades = <String, int>{
      for (final c in comorbidadesDisponiveis) c: n(porComorbidade[c]),
    };

    return _DadosEstatisticas(
      total: n(moradores['total']),
      gestantes: n(moradores['gestantes']),
      criancas: n(moradores['criancas_menores_2_anos']),
      idosos: n(moradores['idosos_60_mais']),
      acamados: n(moradores['acamados']),
      comorbidades: comorbidades,
      microareas: n(json['microareas']),
    );
  }

  void _trocarEscopo(EscopoEstatisticas novo) {
    if (novo == _escopo) return;
    setState(() {
      _escopo = novo;
      _carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => setState(_carregar),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<EscopoEstatisticas>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EscopoEstatisticas.minhaArea,
                    label: Text('Minha área'),
                  ),
                  ButtonSegment(
                    value: EscopoEstatisticas.todasAsAreas,
                    label: Text('Todas as áreas'),
                  ),
                ],
                selected: {_escopo},
                onSelectionChanged: (selecao) => _trocarEscopo(selecao.first),
              ),
            ),
          ),
          Expanded(child: _conteudo()),
        ],
      ),
    );
  }

  Widget _conteudo() {
    return FutureBuilder<_DadosEstatisticas>(
      future: _dadosFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _mensagemErro();
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dados = snapshot.data!;

        if (dados.total == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _soMinhaArea
                    ? 'Nenhum morador cadastrado ainda nesta área.'
                    : 'Nenhum morador cadastrado ainda.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }

        final maiorComorbidade =
            dados.comorbidades.values.fold<int>(0, (a, b) => a > b ? a : b);

        final legendaTotal = _soMinhaArea
            ? 'moradores cadastrados em ${widget.nomeTerritorio ?? 'sua área'}'
            : 'moradores cadastrados em ${dados.microareas} '
                '${dados.microareas == 1 ? 'microárea' : 'microáreas'}';

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
                    Text(legendaTotal,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black54)),
                    if (!_soMinhaArea) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Soma de todas as microáreas. Não mostra nomes nem endereços.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
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
    );
  }

  Widget _mensagemErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              _soMinhaArea
                  ? 'Não foi possível carregar as estatísticas.'
                  : 'Não foi possível carregar as estatísticas de todas as áreas. '
                      'Elas precisam de internet. Verifique a conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(_carregar),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
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

  /// Quantidade de microáreas somadas (só preenchido em "Todas as áreas").
  final int microareas;

  _DadosEstatisticas({
    required this.total,
    required this.gestantes,
    required this.criancas,
    required this.idosos,
    required this.acamados,
    required this.comorbidades,
    this.microareas = 0,
  });
}