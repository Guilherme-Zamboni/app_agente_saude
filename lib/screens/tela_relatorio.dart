import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/relatorio_dao.dart';
import '../services/relatorio_service.dart';

class TelaRelatorio extends StatefulWidget {
  final String territorioId;
  final String nomeTerritorio;
  final String nomeAgente;

  const TelaRelatorio({
    super.key,
    required this.territorioId,
    required this.nomeTerritorio,
    required this.nomeAgente,
  });

  @override
  State<TelaRelatorio> createState() => _TelaRelatorioState();
}

class _TelaRelatorioState extends State<TelaRelatorio> {
  final _relatorioDao = RelatorioDao();

  late int _ano;
  late int _mes;
  bool _gerando = false;
  bool _incluirNomes = false;
  DadosRelatorio? _previa;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _ano = agora.year;
    _mes = agora.month;
    _carregarPrevia();
  }

  Future<void> _carregarPrevia() async {
    setState(() => _previa = null);
    final dados = await _relatorioDao.gerar(
      territorioId: widget.territorioId,
      ano: _ano,
      mes: _mes,
    );
    if (mounted) setState(() => _previa = dados);
  }

  void _mudarMes(int passos) {
    var novoMes = _mes + passos;
    var novoAno = _ano;
    if (novoMes < 1) {
      novoMes = 12;
      novoAno--;
    } else if (novoMes > 12) {
      novoMes = 1;
      novoAno++;
    }

    final agora = DateTime.now();
    if (novoAno > agora.year ||
        (novoAno == agora.year && novoMes > agora.month)) {
      return;
    }

    setState(() {
      _mes = novoMes;
      _ano = novoAno;
    });
    _carregarPrevia();
  }

  Future<void> _compartilhar() async {
    if (_previa == null) return;
    setState(() => _gerando = true);

    try {
      await RelatorioService.compartilhar(
        dados: _previa!,
        nomeTerritorio: widget.nomeTerritorio,
        nomeAgente: widget.nomeAgente,
        ano: _ano,
        mes: _mes,
        incluirNomes: _incluirNomes,
      );
    } catch (e) {
      _avisar('Não foi possível gerar o relatório: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _salvarNoCelular() async {
    if (_previa == null) return;
    setState(() => _gerando = true);

    try {
      final bytes = await RelatorioService.montar(
        dados: _previa!,
        nomeTerritorio: widget.nomeTerritorio,
        nomeAgente: widget.nomeAgente,
        ano: _ano,
        mes: _mes,
        incluirNomes: _incluirNomes,
      );

      final pasta = await getApplicationDocumentsDirectory();
      final nome = RelatorioService.nomeArquivo(
        nomeTerritorio: widget.nomeTerritorio,
        ano: _ano,
        mes: _mes,
      );
      final arquivo = File('${pasta.path}/$nome');
      await arquivo.writeAsBytes(bytes);

      _avisar('Relatório salvo no aplicativo como $nome');
    } catch (e) {
      _avisar('Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final noMesAtual = _ano == agora.year && _mes == agora.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório mensal')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed:
                        (_previa == null || _gerando) ? null : _salvarNoCelular,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Salvar'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_previa == null || _gerando) ? null : _compartilhar,
                    icon: _gerando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.share),
                    label: Text(_gerando ? 'Gerando...' : 'Compartilhar PDF',
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 30),
                    onPressed: () => _mudarMes(-1),
                  ),
                  Column(
                    children: [
                      Text('${nomesMeses[_mes - 1]} de $_ano',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.nomeTerritorio,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        size: 30, color: noMesAtual ? Colors.black26 : null),
                    onPressed: noMesAtual ? null : () => _mudarMes(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_previa == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _secao(
              'Visitas no mês',
              [
                _linha('Total de visitas realizadas',
                    '${_previa!.totalVisitas}',
                    destaque: true),
                _linha('Idas com moradores ausentes',
                    '${_previa!.tentativasAusentes}'),
                _linha('Recusadas', '${_previa!.visitasRecusadas}'),
                _linha('Casas sem contato no mês',
                    '${_previa!.casasSemContato}'),
                _comparativo(),
              ],
              rodape: 'Cada ida à casa é contada, mesmo em retornos ao '
                  'mesmo domicílio.',
            ),
            _secao('Cadastros total', [
              _linha('Domicílios', '${_previa!.totalDomicilios}'),
              _linha('Moradores', '${_previa!.totalMoradores}'),
            ]),
            _secao('Situação da microárea', [
              _linha('Total de domicílios', '${_previa!.totalDomicilios}'),
              _linha('Casas não cadastradas', '${_previa!.naoCadastradas}'),
              _linha('Casas sem contato no mês',
                  '${_previa!.casasSemContato}'),
              _linha('Pendentes de visita', '${_previa!.pendentesVisita}'),
            ]),
            _secao(
              'População acompanhada no mês',
              [
                _linha('Moradores', _previa!.moradores.texto),
                _linha('Gestantes', _previa!.gestantes.texto),
                _linha('Menores de 2 anos', _previa!.criancas.texto),
                _linha('Idosos (60+)', _previa!.idosos.texto),
                _linha('Acamados', _previa!.acamados.texto),
              ],
              rodape: 'Quantos receberam visita com contato no mês, '
                  'em relação ao total cadastrado.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Incluir nomes no PDF',
                          style: TextStyle(fontSize: 15)),
                      subtitle: const Text(
                          'Lista quem dos grupos prioritários ficou sem visita'),
                      value: _incluirNomes,
                      onChanged: (v) => setState(() => _incluirNomes = v),
                    ),
                    if (_incluirNomes)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.privacy_tip_outlined,
                                size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'O arquivo conterá nomes de moradores. '
                                'Compartilhe apenas com a coordenação.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O PDF inclui também as comorbidades acompanhadas e a lista '
              'detalhada das visitas do mês.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparativo() {
    final d = _previa!;
    if (d.totalVisitasMesAnterior == 0 && d.totalVisitas == 0) {
      return const SizedBox.shrink();
    }

    final diferenca = d.diferencaVisitas;
    final mesAnterior = nomesMeses[(_mes == 1 ? 12 : _mes - 1) - 1];

    final texto = diferenca == 0
        ? 'Mesmo número de $mesAnterior (${d.totalVisitasMesAnterior})'
        : diferenca > 0
            ? '$diferenca a mais que em $mesAnterior (${d.totalVisitasMesAnterior})'
            : '${diferenca.abs()} a menos que em $mesAnterior (${d.totalVisitasMesAnterior})';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            diferenca > 0
                ? Icons.trending_up
                : diferenca < 0
                    ? Icons.trending_down
                    : Icons.trending_flat,
            size: 18,
            color: diferenca >= 0 ? Colors.green[700] : Colors.orange[800],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 13,
                    color:
                        diferenca >= 0 ? Colors.green[800] : Colors.orange[900])),
          ),
        ],
      ),
    );
  }

  Widget _secao(String titulo, List<Widget> linhas, {String? rodape}) {
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
            if (rodape != null) ...[
              const SizedBox(height: 8),
              Text(rodape,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor, {bool destaque = false}) {
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
          Text(valor,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: destaque ? Colors.teal : null)),
        ],
      ),
    );
  }
}