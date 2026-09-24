import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/domicilio.dart';
import '../models/visita.dart';
import '../database/domicilio_dao.dart';
import '../database/visita_dao.dart';
import '../database/morador_dao.dart';
import '../services/auth_service.dart';
import '../widgets/barra_sincronizacao.dart';
import '../widgets/dialogo_visita.dart';
import 'tela_cadastro_domicilio.dart';
import 'tela_detalhe_domicilio.dart';
import 'tela_busca_moradores.dart';
import 'tela_estatisticas.dart';
import 'tela_selecionar_local_mapa.dart';
import 'tela_relatorio.dart';

const int diasLimiteVisita = 30;

const Color corPendente = Color(0xFF546E7A);
const Color corNaoCadastrada = Color(0xFF8E24AA);

enum FiltroMapa {
  todos,
  pendentes,
  visitados,
  ausentes,
  naoCadastradas,
  gestante,
  crianca,
  idoso,
  acamado,
  hipertensao,
  diabetes,
}

const Map<FiltroMapa, String> rotulosFiltro = {
  FiltroMapa.todos: 'Todos',
  FiltroMapa.pendentes: 'Pendentes de visita',
  FiltroMapa.visitados: 'Visitados (30 dias)',
  FiltroMapa.ausentes: 'Ausentes ou recusadas',
  FiltroMapa.naoCadastradas: 'Casas não cadastradas',
  FiltroMapa.gestante: 'Com gestante',
  FiltroMapa.crianca: 'Com criança (menor de 2 anos)',
  FiltroMapa.idoso: 'Com idoso (60+)',
  FiltroMapa.acamado: 'Com acamado',
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
  final Map<String, Visita> ultimasVisitas;
  final Map<String, Set<String>> marcadores;
  final Set<String> naoCadastrados;

  _DadosMapa(this.domicilios, this.ultimasVisitas, this.marcadores,
      this.naoCadastrados);
}

class _TelaMapaTerritorioState extends State<TelaMapaTerritorio> {
  final _domicilioDao = DomicilioDao();
  final _visitaDao = VisitaDao();
  final _moradorDao = MoradorDao();
  late Future<_DadosMapa> _dadosFuture;
  final _controladorZoom = TransformationController();
  final _chaveMapa = GlobalKey();
  final _chaveSync = GlobalKey<BarraSincronizacaoState>();
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

  void _recarregarTudo() {
    setState(_carregar);
    _chaveSync.currentState?.atualizarStatusExterno();
  }

  Future<_DadosMapa> _buscarDados() async {
    final domicilios =
        await _domicilioDao.listarPorTerritorio(widget.territorioId);
    final visitas =
        await _visitaDao.ultimaVisitaPorDomicilio(widget.territorioId);
    final marcadores =
        await _moradorDao.marcadoresPorDomicilio(widget.territorioId);
    final naoCadastrados =
        await _domicilioDao.idsNaoCadastrados(widget.territorioId);
    return _DadosMapa(domicilios, visitas, marcadores, naoCadastrados);
  }

  Future<void> _focarDestacado() async {
    final dados = await _dadosFuture;
    final alvo = dados.domicilios.firstWhereOrNull((d) => d.id == _destacado);
    if (alvo == null || alvo.posX == null || alvo.posY == null) return;
    if (!mounted) return;

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

  bool _estaEmDia(Visita? ultima) {
    if (ultima == null) return false;
    return DateTime.now().difference(ultima.dataVisita).inDays <=
        diasLimiteVisita;
  }

  /// Cor do pino conforme a situação do domicílio.
  Color _corDoPino(Domicilio d, _DadosMapa dados) {
    if (dados.naoCadastrados.contains(d.id)) return corNaoCadastrada;

    final ultima = dados.ultimasVisitas[d.id];
    if (!_estaEmDia(ultima)) return corPendente;

    return corResultado(ultima!.resultado);
  }

  bool _passaNoFiltro(Domicilio d, _DadosMapa dados) {
    final ultima = dados.ultimasVisitas[d.id];
    final emDia = _estaEmDia(ultima);
    final marcadores = dados.marcadores[d.id] ?? <String>{};

    switch (_filtroAtual) {
      case FiltroMapa.todos:
        return true;
      case FiltroMapa.pendentes:
        return !emDia;
      case FiltroMapa.visitados:
        return emDia;
      case FiltroMapa.ausentes:
        return emDia && ultima!.resultado != 'realizada';
      case FiltroMapa.naoCadastradas:
        return dados.naoCadastrados.contains(d.id);
      case FiltroMapa.gestante:
        return marcadores.contains('gestante');
      case FiltroMapa.crianca:
        return marcadores.contains('crianca');
      case FiltroMapa.idoso:
        return marcadores.contains('idoso');
      case FiltroMapa.acamado:
        return marcadores.contains('acamado');
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

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do aplicativo'),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await AuthService.sair();
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
    _recarregarTudo();
  }

  Future<void> _abrirDetalhe(Domicilio domicilio) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaDetalheDomicilio(domicilio: domicilio)),
    );
    _recarregarTudo();
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
    _recarregarTudo();
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
      _recarregarTudo();
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
      _recarregarTudo();
    }
  }

  String _textoUltimaVisita(Visita? ultima) {
    if (ultima == null) return 'Nunca visitado';

    final dias = DateTime.now().difference(ultima.dataVisita).inDays;
    final data = '${ultima.dataVisita.day.toString().padLeft(2, '0')}/'
        '${ultima.dataVisita.month.toString().padLeft(2, '0')}/'
        '${ultima.dataVisita.year}';

    final quando = dias == 0
        ? 'hoje'
        : dias == 1
            ? 'ontem'
            : 'há $dias dias';

    return '${rotulosResultado[ultima.resultado]} $quando ($data)';
  }

  void _abrirMenuCasa(Domicilio d, Visita? ultima, bool naoCadastrada) {
    final emDia = _estaEmDia(ultima);
    final cor = ultima == null || !emDia
        ? Colors.orange.shade800
        : corResultado(ultima.resultado);
    final fundo = ultima == null || !emDia
        ? const Color(0xFFFFF3E0)
        : ultima.resultado == 'realizada'
            ? const Color(0xFFE8F5E9)
            : ultima.resultado == 'ausente'
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFFFEBEE);

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
            if (naoCadastrada)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.house_outlined, color: corNaoCadastrada),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Casa não cadastrada',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    ultima == null || !emDia
                        ? Icons.warning_amber_rounded
                        : iconeResultado(ultima.resultado),
                    color: cor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _textoUltimaVisita(ultima),
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
              title: Text(naoCadastrada
                  ? 'Abrir casa / cadastrar família'
                  : 'Ver famílias e moradores'),
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
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Relatório mensal',
            onPressed: () async {
              final perfil = await AuthService.carregarPerfil();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaRelatorio(
                    territorioId: widget.territorioId,
                    nomeTerritorio: widget.nomeTerritorio,
                    nomeAgente: perfil?.nome ?? 'Agente',
                  ),
                ),
              );
            },
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
                MaterialPageRoute(
                  builder: (_) => TelaBuscaMoradores(
                    territorioId: widget.territorioId,
                    nomeTerritorio: widget.nomeTerritorio,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _sair,
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

          final visiveis = todos.where((d) => _passaNoFiltro(d, dados)).toList();
          final pendentes = todos
              .where((d) => !_estaEmDia(dados.ultimasVisitas[d.id]))
              .length;

          return Column(
            children: [
              BarraSincronizacao(
                key: _chaveSync,
                territorioId: widget.territorioId,
                aoSincronizar: () => setState(_carregar),
              ),
              if (todos.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 64, color: Colors.black26),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum domicílio cadastrado ainda neste território.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.black54),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Toque em "Novo domicílio" para começar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black38),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
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
                                        _construirPino(d, dados, largura, altura),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
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
                              _itemLegenda(corResultado('realizada'), 'Visitado'),
                              _itemLegenda(corResultado('ausente'), 'Ausente'),
                              _itemLegenda(corResultado('recusada'), 'Recusada'),
                              _itemLegenda(corPendente, 'Pendente'),
                              _itemLegenda(corNaoCadastrada, 'Não cadastrada'),
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
                              child:
                                  const Icon(Icons.remove, color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _itemLegenda(Color cor, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: cor, size: 16),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _construirPino(
    Domicilio d,
    _DadosMapa dados,
    double largura,
    double altura,
  ) {
    final cor = _corDoPino(d, dados);
    final naoCadastrada = dados.naoCadastrados.contains(d.id);
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
            onTap: () =>
                _abrirMenuCasa(d, dados.ultimasVisitas[d.id], naoCadastrada),
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
                  naoCadastrada ? Icons.help_center : Icons.location_on,
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