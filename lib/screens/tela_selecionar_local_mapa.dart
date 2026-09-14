import 'package:flutter/material.dart';

class TelaSelecionarLocalMapa extends StatefulWidget {
  final double? posXInicial;
  final double? posYInicial;

  const TelaSelecionarLocalMapa({super.key, this.posXInicial, this.posYInicial});

  @override
  State<TelaSelecionarLocalMapa> createState() => _TelaSelecionarLocalMapaState();
}

class _TelaSelecionarLocalMapaState extends State<TelaSelecionarLocalMapa> {
  final _controladorZoom = TransformationController();
  final _chaveMapa = GlobalKey();
  double _escalaAtual = 1.0;

  // TROQUE pelos números reais da sua imagem (largura / altura)
  static const double _proporcaoMapa = 1024 / 764;

  Offset? _posicaoSelecionada; // proporção 0.0 a 1.0

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
  }

  @override
  void dispose() {
    _controladorZoom.dispose();
    super.dispose();
  }

  void _ajustarZoom(double fator) {
    final tamanho = context.size;
    if (tamanho == null) return;

    // ancora o zoom no centro da tela, para não perder o enquadramento
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

  @override
  Widget build(BuildContext context) {
    final temPosicao = _posicaoSelecionada != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indique a localização'),
      ),
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

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _aoTocarNoMapa,
                      child: Stack(
                        key: _chaveMapa,
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/maps/territorio_teste.jpg',
                            width: largura,
                            height: altura,
                            fit: BoxFit.fill,
                          ),
                          if (_posicaoSelecionada != null)
                            Positioned(
                              left: _posicaoSelecionada!.dx * largura,
                              top: _posicaoSelecionada!.dy * altura,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -1.0),
                                child: Transform.scale(
                                  scale: 1 / _escalaAtual,
                                  alignment: Alignment.bottomCenter,
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: 36),
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
              child: const Text(
                'Toque no local do mapa onde fica esta casa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              children: [
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