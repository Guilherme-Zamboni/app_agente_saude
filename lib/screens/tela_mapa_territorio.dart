import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/domicilio.dart';
import '../database/domicilio_dao.dart';
import '../database/visita_dao.dart';
import '../database/morador_dao.dart';
import 'tela_cadastro_domicilio.dart';
import 'tela_detalhe_domicilio.dart';
import 'tela_busca_moradores.dart';
import 'tela_estatisticas.dart';
import 'tela_selecionar_local_mapa.dart';

const int diasLimiteVisita = 30;

enum FiltroMapa {
  todos,
  pendentes,
  visitados,
  gestante,
  crianca,
  idoso,
  hipertensao,
  diabetes,
}

const Map<FiltroMapa, String> rotulosFiltro = {
  FiltroMapa.todos: 'Todos',
  FiltroMapa.pendentes: 'Pendentes de visita',
  FiltroMapa.visitados: 'Visitados (30 dias)',
  FiltroMapa.gestante: 'Com gestante',
  FiltroMapa.crianca: 'Com criança (0-4)',
  FiltroMapa.idoso: 'Com idoso (60+)',
  FiltroMapa.hipertensao: 'Com hipertensão',
  FiltroMapa.diabetes: 'Com diabetes',
};

class TelaMapaTerritorio extends StatefulWidget {
  final String territorioId;
  final String nomeTerritorio;
  final String? domicilioDestacado;

  const TelaMapaTerritorio({
    super.key,
    required this.territorioId,
    required this.nomeTerritorio,
    this.domicilioDestacado,
  });

  @override
  State<TelaMapaTerritorio> createState() => _TelaMapaTerritorioState();
}

class _DadosMapa {
  final List<Domicilio> domicilios;
  final Map<String, DateTime> ultimasVisitas;
  final Map<String, Set<String>> marcadores;

  _DadosMapa(this.domicilios, this.ultimasVisitas, this.marcadores);
}

class _TelaMapaTerritorioState extends State<TelaMapaTerritorio> {
  final _domicilioDao = DomicilioDao();
  final _visitaDao = VisitaDao();
  final _moradorDao = MoradorDao();
  late Future<_DadosMapa> _dadosFuture;
  final _controladorZoom = TransformationController();
  final _chaveMapa = GlobalKey();
  double _escalaAtual = 1.0;
  FiltroMapa _filtroAtual = FiltroMapa.todos;
  String? _destacado;

  // TROQUE pelos números reais da sua imagem (largura / altura)
  static const double _proporcaoMapa = 1200 / 900;

  @override
  void initState() {
    super.initState();
    _destacado = widget.domicilioDestacado;
    _carregar();
    _controladorZoom.addListener(() {
      final escala = _controladorZoom.value.getMaxScaleOnAxis();
      if (escala != _escalaAtual) {
        setState(() => _escalaAtual = escala);
      }
    });

    if (_destacado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focarDestacado());
    }
  }

  @override
  void dispose() {
    _controladorZoom.dispose();
    super.dispose();
  }

  void _carregar() {
    _dadosFuture = _buscarDados();
  }

  Future<_DadosMapa> _buscarDados() async {
    final domicilios =
        await _domicilioDao.listarPorTerritorio(widget.territorioId);
    final visitas =
        await _visitaDao.ultimasVisitasPorTerritorio(widget.territorioId);
    final marcadores =
        await _moradorDao.marcadoresPorDomicilio(widget.territorioId);
    return _DadosMapa(domicilios, visitas, marcadores);
  }

  Future<void> _focarDestacado() async {
    final dados = await _dadosFuture;
    final alvo = dados.domicilios.firstWhereOrNull((d) => d.id == _destacado);
    if (alvo == null || alvo.posX == null || alvo.posY == null) return;
    if (!mounted) return;

    // espera o mapa terminar de ser desenhado antes de medir
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final boxMapa = _chaveMapa.currentContext?.findRenderObject() as RenderBox?;
    final boxViewport = context.findRenderObject() as RenderBox?;
    if (boxMapa == null || boxViewport == null) return;

    final tamanhoMapa = boxMapa.size;
    final tamanhoTela = boxViewport.size;

    const escala = 2.5;

    final alvoX = alvo.posX! * tamanhoMapa.width * escala;
    final alvoY = alvo.posY! * tamanhoMapa.height * escala;

    final matriz = Matrix4.identity()
      ..scale(escala, escala, 1.0)
      ..setTranslationRaw(
        tamanhoTela.width / 2 - alvoX,
        tamanhoTela.height / 2 - alvoY,
        0,
      );

    setState(() => _controladorZoom.value = matriz);
  }

  bool _estaEmDia(DateTime? ultimaVisita) {
    if (ultimaVisita == null) return false;
    return DateTime.now().difference(ultimaVisita).inDays <= diasLimiteVisita;
  }

  bool _passaNoFiltro(Domicilio d, _DadosMapa dados) {
    final emDia = _estaEmDia(dados.ultimasVisitas[d.id]);
    final marcadores = dados.marcadores[d.id] ?? <String>{};

    switch (_filtroAtual) {
      case FiltroMapa.todos:
        return true;
      case FiltroMapa.pendentes:
        return !emDia;
      case FiltroMapa.visitados:
        return emDia;
      case FiltroMapa.gestante:
        return marcadores.contains('gestante');
      case FiltroMapa.crianca:
        return marcadores.contains('crianca');
      case FiltroMapa.idoso:
        return marcadores.contains('idoso');
      case FiltroMapa.hipertensao:
        return marcadores.contains('hipertensao');
      case FiltroMapa.diabetes:
        return marcadores.contains('diabetes');
    }
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

  void _resetarZoom() {
    setState(() {
      _controladorZoom.value = Matrix4.identity();
      _destacado = null;
    });
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final filtro in FiltroMapa.values)
                      ListTile(
                        leading: Icon(
                          _filtroAtual == filtro
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _filtroAtual == filtro
                              ? Colors.teal
                              : Colors.black38,
                        ),
                        title: Text(rotulosFiltro[filtro]!),
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

  Future<void> _abrirNovoDomicilio() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroDomicilio(territorioId: widget.territorioId),
      ),
    );
    setState(_carregar);
  }

  Future<void> _abrirDetalhe(Domicilio domicilio) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaDetalheDomicilio(domicilio: domicilio)),
    );
    setState(_carregar);
  }

  Future<void> _abrirEdicao(Domicilio domicilio) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroDomicilio(
          territorioId: widget.territorioId,
          domicilioParaEditar: domicilio,
        ),
      ),
    );
    setState(_carregar);
  }

  Future<void> _moverNoMapa(Domicilio domicilio) async {
    final posicao = await Navigator.push<Offset?>(
      context,
      MaterialPageRoute(
        builder: (_) => TelaSelecionarLocalMapa(
          posXInicial: domicilio.posX,
          posYInicial: domicilio.posY,
        ),
      ),
    );
    if (posicao != null) {
      await _domicilioDao.atualizarPosicao(domicilio.id, posicao.dx, posicao.dy);
      setState(_carregar);
    }
  }

  Future<void> _confirmarExclusao(Domicilio domicilio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir domicílio'),
        content: Text(
          'Isso vai remover "${domicilio.rua}, ${domicilio.numero}" e todas '
          'as famílias e moradores cadastrados nele. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _domicilioDao.inativar(domicilio.id);
      setState(_carregar);
    }
  }

  String _textoUltimaVisita(DateTime? ultimaVisita) {
    if (ultimaVisita == null) return 'Nunca visitado';

    final dias = DateTime.now().difference(ultimaVisita).inDays;
    final dataFormatada = '${ultimaVisita.day.toString().padLeft(2, '0')}/'
        '${ultimaVisita.month.toString().padLeft(2, '0')}/${ultimaVisita.year}';

    if (dias == 0) return 'Visitado hoje ($dataFormatada)';
    if (dias == 1) return 'Visitado ontem ($dataFormatada)';
    return 'Última visita há $dias dias ($dataFormatada)';
  }

  void _abrirMenuCasa(Domicilio d, DateTime? ultimaVisita) {
    final emDia = _estaEmDia(ultimaVisita);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${d.rua}, ${d.numero}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(d.bairro),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: emDia ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    emDia ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    color: emDia ? Colors.green[700] : Colors.orange[800],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _textoUltimaVisita(ultimaVisita),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Ver famílias e moradores'),
              onTap: () {
                Navigator.pop(context);
                _abrirDetalhe(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar endereço'),
              onTap: () {
                Navigator.pop(context);
                _abrirEdicao(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_drop_outlined),
              title: const Text('Mover posição no mapa'),
              onTap: () {
                Navigator.pop(context);
                _moverNoMapa(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Excluir domicílio',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _confirmarExclusao(d);
              },
            ),
            const SizedBox(height: 8),
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
            icon: Icon(_filtroAtual == FiltroMapa.todos
                ? Icons.filter_alt_outlined
                : Icons.filter_alt),
            tooltip: 'Filtrar',
            onPressed: _abrirFiltro,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Estatísticas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaEstatisticas()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar morador',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaBuscaMoradores()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNovoDomicilio,
        icon: const Icon(Icons.add_home),
        label: const Text('Novo domicílio'),
      ),
      body: FutureBuilder<_DadosMapa>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final dados = snapshot.data!;
          final todos = dados.domicilios;

          if (todos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_outlined, size: 64, color: Colors.black26),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum domicílio cadastrado ainda neste território.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toque em "Novo domicílio" para começar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            );
          }

          final visiveis = todos.where((d) => _passaNoFiltro(d, dados)).toList();
          final pendentes =
              todos.where((d) => !_estaEmDia(dados.ultimasVisitas[d.id])).length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.teal.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.home_work_outlined,
                        size: 20, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _filtroAtual == FiltroMapa.todos
                            ? '${todos.length} domicílios • $pendentes pendente(s) de visita'
                            : '${visiveis.length} de ${todos.length} • ${rotulosFiltro[_filtroAtual]}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (_filtroAtual != FiltroMapa.todos)
                      TextButton(
                        onPressed: () =>
                            setState(() => _filtroAtual = FiltroMapa.todos),
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
                          key: _chaveMapa,
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
                                      _construirPino(
                                        d,
                                        dados.ultimasVisitas[d.id],
                                        largura,
                                        altura,
                                      ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 3),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.location_on,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 4),
                                Text('Visitado', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.location_on,
                                    color: Color(0xFF546E7A), size: 18),
                                SizedBox(width: 4),
                                Text('Pendente', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'centralizar',
                            backgroundColor: Colors.white,
                            onPressed: _resetarZoom,
                            child: const Icon(Icons.center_focus_strong,
                                color: Colors.teal),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'zoomIn',
                            backgroundColor: Colors.white,
                            onPressed: () => _ajustarZoom(1.2),
                            child: const Icon(Icons.add, color: Colors.teal),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'zoomOut',
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

  Widget _construirPino(
    Domicilio d,
    DateTime? ultimaVisita,
    double largura,
    double altura,
  ) {
    final emDia = _estaEmDia(ultimaVisita);
    final cor = emDia ? Colors.green[600]! : const Color(0xFF546E7A);
    final destacado = d.id == _destacado;

    return Positioned(
      left: d.posX! * largura,
      top: d.posY! * altura,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.0),
        child: Transform.scale(
          scale: 1 / _escalaAtual,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _abrirMenuCasa(d, ultimaVisita),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (destacado)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('encontrado',
                        style: TextStyle(fontSize: 9, color: Colors.white)),
                  ),
                Icon(
                  Icons.location_on,
                  color: destacado ? Colors.amber[800] : cor,
                  size: destacado ? 46 : 36,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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