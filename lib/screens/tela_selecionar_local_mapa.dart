import 'package:flutter/material.dart';

class TelaSelecionarLocalMapa extends StatefulWidget {
  final double? posXInicial;
  final double? posYInicial;

  const TelaSelecionarLocalMapa({super.key, this.posXInicial, this.posYInicial});

  @override
  State<TelaSelecionarLocalMapa> createState() => _TelaSelecionarLocalMapaState();
}

class _TelaSelecionarLocalMapaState extends State<TelaSelecionarLocalMapa> {
  static const double _larguraMapa = 1200;
  static const double _alturaMapa = 1200;

  final _controladorZoom = TransformationController();
  final _chaveMapa = GlobalKey(); // referência ao próprio mapa, para medir o toque

  Offset? _posicaoSelecionada; // coordenadas relativas, 0.0 a 1.0

  @override
  void initState() {
    super.initState();
    if (widget.posXInicial != null && widget.posYInicial != null) {
      _posicaoSelecionada = Offset(widget.posXInicial!, widget.posYInicial!);
    }
  }

  @override
  void dispose() {
    _controladorZoom.dispose();
    super.dispose();
  }

  void _ajustarZoom(double fator) {
    final matrizAtual = _controladorZoom.value.clone();
    setState(() {
      _controladorZoom.value = matrizAtual..scale(fator, fator, 1.0);
    });
  }

  void _aoTocarNoMapa(TapDownDetails details) {
    // Mede em relação ao próprio SizedBox do mapa (via GlobalKey),
    // e não em relação à tela inteira - isso mantém a conta correta
    // mesmo com zoom, arraste ou camadas extras em volta.
    final box = _chaveMapa.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _posicaoSelecionada = Offset(
        (local.dx / _larguraMapa).clamp(0.0, 1.0),
        (local.dy / _alturaMapa).clamp(0.0, 1.0),
      );
    });
  }

  void _confirmar() {
    if (_posicaoSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toque no mapa para indicar o local da casa')),
      );
      return;
    }
    Navigator.pop(context, _posicaoSelecionada);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indique a localização'),
        actions: [
          TextButton(
            onPressed: _confirmar,
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Toque no local do mapa onde fica esta casa.',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _controladorZoom,
                  minScale: 0.5,
                  maxScale: 3,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: GestureDetector(
                    onTapDown: _aoTocarNoMapa,
                    child: SizedBox(
                      key: _chaveMapa,
                      width: _larguraMapa,
                      height: _alturaMapa,
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/maps/territorio_teste.jpg',
                            width: _larguraMapa,
                            height: _alturaMapa,
                            fit: BoxFit.cover,
                          ),
                          if (_posicaoSelecionada != null)
                            Positioned(
                              left: _posicaoSelecionada!.dx * _larguraMapa - 20,
                              top: _posicaoSelecionada!.dy * _alturaMapa - 40,
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 40),
                            ),
                        ],
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
          ),
        ],
      ),
    );
  }
}