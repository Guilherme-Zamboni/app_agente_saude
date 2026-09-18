import 'package:flutter/material.dart';
import '../models/domicilio.dart';
import '../models/familia.dart';
import '../models/morador.dart';
import '../services/consulta_service.dart';
import 'tela_busca_consulta.dart';
import 'tela_ficha_consulta.dart';

const int _diasLimiteVisita = 30;

enum FiltroConsulta {
  todos,
  pendentes,
  visitados,
  gestante,
  crianca,
  idoso,
  hipertensao,
  diabetes,
}

const Map<FiltroConsulta, String> _rotulosFiltro = {
  FiltroConsulta.todos: 'Todos',
  FiltroConsulta.pendentes: 'Pendentes de visita',
  FiltroConsulta.visitados: 'Visitados (30 dias)',
  FiltroConsulta.gestante: 'Com gestante',
  FiltroConsulta.crianca: 'Com criança (0-4)',
  FiltroConsulta.idoso: 'Com idoso (60+)',
  FiltroConsulta.hipertensao: 'Com hipertensão',
  FiltroConsulta.diabetes: 'Com diabetes',
};

class TelaMapaConsulta extends StatefulWidget {
  final String territorioId;
  final String nomeTerritorio;
  final String? nomeAgente;

  const TelaMapaConsulta({
    super.key,
    required this.territorioId,
    required this.nomeTerritorio,
    this.nomeAgente,
  });

  @override
  State<TelaMapaConsulta> createState() => _TelaMapaConsultaState();
}

class _Dados {
  final List<Domicilio> domicilios;
  final Map<String, DateTime> ultimasVisitas;
  final Map<String, Set<String>> marcadores;

  _Dados(this.domicilios, this.ultimasVisitas, this.marcadores);
}

class _TelaMapaConsultaState extends State<TelaMapaConsulta> {
  late Future<_Dados> _future;
  final _controladorZoom = TransformationController();
  double _escalaAtual = 1.0;
  FiltroConsulta _filtroAtual = FiltroConsulta.todos;

  // TROQUE pelos números reais da sua imagem (largura / altura)
  static const double _proporcaoMapa = 1200 / 900;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
    _controladorZoom.addListener(() {
      final escala = _controladorZoom.value.getMaxScaleOnAxis();
      if (escala != _escalaAtual) {
        setState(() => _escalaAtual = escala);
      }
    });
  }

  @override
  void dispose() {
    _controladorZoom.dispose();
    super.dispose();
  }

  Future<_Dados> _carregar() async {
    final domicilios =
        await ConsultaService.domiciliosDoTerritorio(widget.territorioId);
    final visitas = await ConsultaService.ultimasVisitas(widget.territorioId);
    final marcadores =
        await ConsultaService.marcadoresPorDomicilio(widget.territorioId);
    return _Dados(domicilios, visitas, marcadores);
  }

  void _ajustarZoom(double fator) {
    final tamanho = context.size;
    if (tamanho == null) return;

    final centro = Offset(tamanho.width / 2, tamanho.height / 2);
    final matriz = _controladorZoom.value.clone();

    final escalaAtual = matriz.getMaxScaleOnAxis();
    final escalaDesejada = (escalaAtual * fator).clamp(1.0, 4.0);
    final fatorReal = escalaDesejada / escalaAtual;
    if (fatorReal == 1.0) return;

    matriz
      ..translate(centro.dx, centro.dy)
      ..scale(fatorReal, fatorReal, 1.0)
      ..translate(-centro.dx, -centro.dy);

    setState(() => _controladorZoom.value = matriz);
  }

  bool _estaEmDia(DateTime? ultima) {
    if (ultima == null) return false;
    return DateTime.now().difference(ultima).inDays <= _diasLimiteVisita;
  }

  bool _passaNoFiltro(Domicilio d, _Dados dados) {
    final emDia = _estaEmDia(dados.ultimasVisitas[d.id]);
    final marcadores = dados.marcadores[d.id] ?? <String>{};

    switch (_filtroAtual) {
      case FiltroConsulta.todos:
        return true;
      case FiltroConsulta.pendentes:
        return !emDia;
      case FiltroConsulta.visitados:
        return emDia;
      case FiltroConsulta.gestante:
        return marcadores.contains('gestante');
      case FiltroConsulta.crianca:
        return marcadores.contains('crianca');
      case FiltroConsulta.idoso:
        return marcadores.contains('idoso');
      case FiltroConsulta.hipertensao:
        return marcadores.contains('hipertensao');
      case FiltroConsulta.diabetes:
        return marcadores.contains('diabetes');
    }
  }

  void _abrirFiltro() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Filtrar domicílios',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final filtro in FiltroConsulta.values)
                      ListTile(
                        leading: Icon(
                          _filtroAtual == filtro
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _filtroAtual == filtro
                              ? Colors.teal
                              : Colors.black38,
                        ),
                        title: Text(_rotulosFiltro[filtro]!),
                        onTap: () {
                          setState(() => _filtroAtual = filtro);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _textoUltimaVisita(DateTime? ultima) {
    if (ultima == null) return 'Nunca visitado';
    final dias = DateTime.now().difference(ultima).inDays;
    final data = '${ultima.day.toString().padLeft(2, '0')}/'
        '${ultima.month.toString().padLeft(2, '0')}/${ultima.year}';
    if (dias == 0) return 'Visitado hoje ($data)';
    if (dias == 1) return 'Visitado ontem ($data)';
    return 'Última visita há $dias dias ($data)';
  }

  void _abrirDomicilio(Domicilio d, DateTime? ultimaVisita) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.rua}, ${d.numero}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(d.bairro, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _estaEmDia(ultimaVisita)
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_textoUltimaVisita(ultimaVisita)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Familia>>(
                future: ConsultaService.familiasDoDomicilio(d.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final familias = snapshot.data!;
                  if (familias.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhuma família cadastrada.'),
                      ),
                    );
                  }
                  return ListView(
                    controller: scrollController,
                    children: familias
                        .map((f) => _CardFamiliaConsulta(familia: f))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeTerritorio),
        actions: [
          IconButton(
            icon: Icon(_filtroAtual == FiltroConsulta.todos
                ? Icons.filter_alt_outlined
                : Icons.filter_alt),
            tooltip: 'Filtrar',
            onPressed: _abrirFiltro,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar morador',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaBuscaConsulta(
                  territorioId: widget.territorioId,
                  nomeTerritorio: widget.nomeTerritorio,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 6, left: 16),
            child: Text(
              widget.nomeAgente != null
                  ? 'Agente: ${widget.nomeAgente} • somente leitura'
                  : 'Somente leitura',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
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

          final dados = snapshot.data!;

          if (dados.domicilios.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum domicílio cadastrado nesta microárea ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }

          final visiveis =
              dados.domicilios.where((d) => _passaNoFiltro(d, dados)).toList();
          final pendentes = dados.domicilios
              .where((d) => !_estaEmDia(dados.ultimasVisitas[d.id]))
              .length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.teal.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.home_work_outlined,
                        size: 20, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _filtroAtual == FiltroConsulta.todos
                            ? '${dados.domicilios.length} domicílios • $pendentes pendente(s) de visita'
                            : '${visiveis.length} de ${dados.domicilios.length} • ${_rotulosFiltro[_filtroAtual]}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (_filtroAtual != FiltroConsulta.todos)
                      TextButton(
                        onPressed: () =>
                            setState(() => _filtroAtual = FiltroConsulta.todos),
                        child: const Text('Limpar'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _controladorZoom,
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _proporcaoMapa,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final largura = constraints.maxWidth;
                              final altura = constraints.maxHeight;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Image.asset(
                                    'assets/maps/territorio_teste.jpg',
                                    width: largura,
                                    height: altura,
                                    fit: BoxFit.fill,
                                  ),
                                  for (final d in visiveis)
                                    if (d.posX != null && d.posY != null)
                                      _pino(d, dados.ultimasVisitas[d.id],
                                          largura, altura),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'zoomInConsulta',
                            backgroundColor: Colors.white,
                            onPressed: () => _ajustarZoom(1.2),
                            child: const Icon(Icons.add, color: Colors.teal),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'zoomOutConsulta',
                            backgroundColor: Colors.white,
                            onPressed: () => _ajustarZoom(1 / 1.2),
                            child: const Icon(Icons.remove, color: Colors.teal),
                          ),
                        ],
                      ),
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

  Widget _pino(
      Domicilio d, DateTime? ultimaVisita, double largura, double altura) {
    final emDia = _estaEmDia(ultimaVisita);
    final cor = emDia ? Colors.green[600]! : const Color(0xFF546E7A);

    return Positioned(
      left: d.posX! * largura,
      top: d.posY! * altura,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.0),
        child: Transform.scale(
          scale: 1 / _escalaAtual,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _abrirDomicilio(d, ultimaVisita),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: cor, size: 36),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                  child: Text(
                    d.numero,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFamiliaConsulta extends StatelessWidget {
  final Familia familia;

  const _CardFamiliaConsulta({required this.familia});

  int _idade(DateTime nascimento) {
    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    return idade;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.family_restroom, color: Colors.teal),
        title:
            const Text('Família', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            familia.observacoes != null ? Text(familia.observacoes!) : null,
        children: [
          FutureBuilder<List<Morador>>(
            future: ConsultaService.moradoresDaFamilia(familia.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final moradores = snapshot.data!;
              if (moradores.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum morador cadastrado.'),
                );
              }
              return Column(
                children: moradores
                    .map((m) => ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(m.nome),
                          subtitle: Text(
                            '${_idade(m.dataNascimento)} anos'
                            '${m.gestante ? ' • Gestante' : ''}'
                            '${m.comorbidades.isNotEmpty ? ' • ${m.comorbidades.join(', ')}' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaFichaConsulta(
                                moradorId: m.id,
                                familiaId: m.familiaId,
                                nomeMorador: m.nome,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}