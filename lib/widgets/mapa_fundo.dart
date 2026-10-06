import 'dart:io';
import 'package:flutter/material.dart';
import '../services/mapa_service.dart';

/// Desenha a imagem de fundo do mapa: a do território, se houver,
/// ou a imagem padrão enquanto baixa ou quando não há nenhuma.
class MapaFundo extends StatefulWidget {
  final String? urlImagem;
  final double largura;
  final double altura;

  const MapaFundo({
    super.key,
    required this.urlImagem,
    required this.largura,
    required this.altura,
  });

  @override
  State<MapaFundo> createState() => _MapaFundoState();
}

class _MapaFundoState extends State<MapaFundo> {
  File? _arquivo;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(MapaFundo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.urlImagem != widget.urlImagem) _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final arquivo = await MapaService.obter(widget.urlImagem);
    if (!mounted) return;
    setState(() {
      _arquivo = arquivo;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_arquivo != null) {
      return Image.file(
        _arquivo!,
        width: widget.largura,
        height: widget.altura,
        fit: BoxFit.fill,
      );
    }

    return Stack(
      children: [
        Image.asset(
          'assets/maps/territorio_teste.jpg',
          width: widget.largura,
          height: widget.altura,
          fit: BoxFit.fill,
        ),
        if (_carregando && widget.urlImagem != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text('Carregando mapa...',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}