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

  Offset? _posicaoSelecionada; // proporção 0.0 a 1.0

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

  void _aoTocarNoMapa(TapUpDetails details) {
    final box = _chaveMapa.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _posicaoSelecionada = Offset(
        (local.dx / box.size.width).clamp(0.0, 1.0),
        (local.dy / box.size.height).clamp(0.0, 1.0),
      );
    });
    debugPrint('>>> TOQUE: resultado=$_posicaoSelecionada');
  }

  void _confirmar() {
    if (_posicaoSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toque no mapa para indicar o local da casa')),
      );
      return;
    }
    debugPrint('>>> CONFIRMAR: devolvendo $_posicaoSelecionada');
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _aoTocarNoMapa,
              child: SizedBox.expand(
                key: _chaveMapa,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/maps/territorio_teste.jpg',
                      fit: BoxFit.contain,
                    ),
                    if (_posicaoSelecionada != null)
                      Align(
                        alignment: Alignment(
                          _posicaoSelecionada!.dx * 2 - 1,
                          _posicaoSelecionada!.dy * 2 - 1,
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 44),
                      ),
                  ],
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