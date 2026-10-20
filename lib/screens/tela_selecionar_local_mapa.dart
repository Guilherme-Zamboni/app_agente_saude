import 'package:flutter/material.dart';
import '../config/mapa_config.dart';
import '../database/domicilio_dao.dart';
import '../models/domicilio.dart';
import '../widgets/mapa_fundo.dart';

const Color _corReferencia = Color(0xFF78909C);

class TelaSelecionarLocalMapa extends StatefulWidget {
  final double? posXInicial;
  final double? posYInicial;
  final String? imagemMapa;
  final double? proporcaoMapa;

  /// Microárea cujas casas já cadastradas aparecem como referência.
  final String? territorioId;

  /// Casa que está sendo movida (não aparece duplicada como referência).
  final String? domicilioIgnorado;

  /// Endereço da casa nova, mostrado no aviso do topo.
  final String? enderecoNovaCasa;

  const TelaSelecionarLocalMapa({
    super.key,
    this.posXInicial,
    this.posYInicial,
    this.imagemMapa,
    this.proporcaoMapa,
    this.territorioId,
    this.domicilioIgnorado,
    this.enderecoNovaCasa,
  });

  @override
  State<TelaSelecionarLocalMapa> createState() =>
      _TelaSelecionarLocalMapaState();
}

class _TelaSelecionarLocalMapaState extends State<TelaSelecionarLocalMapa> {
  final _controladorZoom = TransformationController();
  final _chaveMapa = GlobalKey();
  double _escalaAtual = 1.0;

  Offset? _posicaoSelecionada; // proporção 0.0 a 1.0
  List<Domicilio> _outrasCasas = [];
  bool _mostrarOutras = true;

  double get _proporcaoMapa => widget.proporcaoMapa ?? (1200 / 900);

  @override
  void initState() {
    super.initState();
    if (widget.posXInicial != null && widget.posYInicial != null) {
      _posicaoSelecionada = Offset(widget.posXInicial!, widget.posYInicial!);
    }
    _controladorZoom.addListener(() {
      final escala = _controladorZoom.value.getMaxScaleOnAxis();
      if (escala != _escalaAtual) {
        setState(() => _escalaAtual = escala);
      }
    });
    _carregarOutrasCasas();
  }

  @override
  void dispose() {
    _controladorZoom.dispose();
    super.dispose();
  }

  Future<void> _carregarOutrasCasas() async {
    final territorio = widget.territorioId;
    if (territorio == null) return;

    final lista = await DomicilioDao().listarPorTerritorio(territorio);
    if (!mounted) return;

    setState(() {
      _outrasCasas = lista
          .where((d) =>
              d.id != widget.domicilioIgnorado &&
              d.posX != null &&
              d.posY != null)
          .toList();
    });
  }

  void _ajustarZoom(double fator) {
    final tamanho = context.size;
    if (tamanho == null) return;

    final centro = Offset(tamanho.width / 2, tamanho.height / 2);
    final matriz = _controladorZoom.value.clone();

    final escalaAtual = matriz.getMaxScaleOnAxis();
    final escalaDesejada = (escalaAtual * fator).clamp(1.0, zoomMaximo);
    final fatorReal = escalaDesejada / escalaAtual;
    if (fatorReal == 1.0) return;

    matriz
      ..translate(centro.dx, centro.dy)
      ..scale(fatorReal, fatorReal, 1.0)
      ..translate(-centro.dx, -centro.dy);

    setState(() => _controladorZoom.value = matriz);
  }

  void _aoTocarNoMapa(TapUpDetails details) {
    final box = _chaveMapa.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _posicaoSelecionada = Offset(
        (local.dx / box.size.width).clamp(0.0, 1.0),
        (local.dy / box.size.height).clamp(0.0, 1.0),
      );
    });
  }

  void _confirmar() {
    if (_posicaoSelecionada == null) return;
    Navigator.pop(context, _posicaoSelecionada);
  }

  /// Pino cinza de referência. Não captura toques, para que tocar perto
  /// de uma casa existente continue marcando a posição da casa nova.
  Widget _casaReferencia(Domicilio d, double largura, double altura) {
    return Positioned(
      left: d.posX! * largura,
      top: d.posY! * altura,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1.0),
          child: Transform.scale(
            scale: escalaDoPino(_escalaAtual),
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on,
                    color: _corReferencia, size: tamanhoPino),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 1),
                    ],
                  ),
                  child: Text(
                    d.numero,
                    style: const TextStyle(
                        fontSize: fontePinoNumero,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final temPosicao = _posicaoSelecionada != null;
    final mostrandoReferencias = _mostrarOutras && _outrasCasas.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Indique a localização')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: temPosicao ? _confirmar : null,
              icon: const Icon(Icons.check),
              label: Text(
                temPosicao ? 'Confirmar localização' : 'Toque no mapa primeiro',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // fundo desfocado, atrás do mapa
          Positioned.fill(
            child: FundoMapaDesfocado(urlImagem: widget.imagemMapa),
          ),
          InteractiveViewer(
            transformationController: _controladorZoom,
            minScale: 1,
            maxScale: zoomMaximo,
            child: Center(
              child: AspectRatio(
                aspectRatio: _proporcaoMapa,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final largura = constraints.maxWidth;
                    final altura = constraints.maxHeight;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _aoTocarNoMapa,
                      child: Stack(
                        key: _chaveMapa,
                        clipBehavior: Clip.none,
                        children: [
                          MapaFundo(
                            urlImagem: widget.imagemMapa,
                            largura: largura,
                            altura: altura,
                          ),
                          if (mostrandoReferencias)
                            for (final d in _outrasCasas)
                              _casaReferencia(d, largura, altura),
                          if (_posicaoSelecionada != null)
                            Positioned(
                              left: _posicaoSelecionada!.dx * largura,
                              top: _posicaoSelecionada!.dy * altura,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -1.0),
                                child: Transform.scale(
                                  scale: escalaDoPino(_escalaAtual),
                                  alignment: Alignment.bottomCenter,
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: tamanhoPino),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.enderecoNovaCasa != null
                        ? 'Toque no mapa onde fica ${widget.enderecoNovaCasa}.'
                        : 'Toque no local do mapa onde fica esta casa.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (mostrandoReferencias)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'As casas em cinza já estão cadastradas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
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
                if (_outrasCasas.isNotEmpty) ...[
                  FloatingActionButton.small(
                    heroTag: 'alternarCasas',
                    backgroundColor: Colors.white,
                    tooltip: _mostrarOutras
                        ? 'Ocultar casas cadastradas'
                        : 'Mostrar casas cadastradas',
                    onPressed: () =>
                        setState(() => _mostrarOutras = !_mostrarOutras),
                    child: Icon(
                      _mostrarOutras ? Icons.visibility : Icons.visibility_off,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FloatingActionButton.small(
                  heroTag: 'zoomInSelecao',
                  backgroundColor: Colors.white,
                  onPressed: () => _ajustarZoom(1.2),
                  child: const Icon(Icons.add, color: Colors.teal),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOutSelecao',
                  backgroundColor: Colors.white,
                  onPressed: () => _ajustarZoom(1 / 1.2),
                  child: const Icon(Icons.remove, color: Colors.teal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}