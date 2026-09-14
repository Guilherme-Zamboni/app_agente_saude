import 'package:flutter/material.dart';
import '../models/domicilio.dart';
import '../database/domicilio_dao.dart';
import 'tela_cadastro_domicilio.dart';
import 'tela_detalhe_domicilio.dart';
import 'tela_busca_moradores.dart';
import 'tela_estatisticas.dart';
import 'tela_selecionar_local_mapa.dart';

class TelaMapaTerritorio extends StatefulWidget {
  final String territorioId;
  final String nomeTerritorio;

  const TelaMapaTerritorio({
    super.key,
    required this.territorioId,
    required this.nomeTerritorio,
  });

  @override
  State<TelaMapaTerritorio> createState() => _TelaMapaTerritorioState();
}

class _TelaMapaTerritorioState extends State<TelaMapaTerritorio> {
  final _domicilioDao = DomicilioDao();
  late Future<List<Domicilio>> _domiciliosFuture;
  final _controladorZoom = TransformationController();
  double _escalaAtual = 1.0;

  // TROQUE pelos números reais da sua imagem (largura / altura)
  static const double _proporcaoMapa = 1074 / 764;

  @override
  void initState() {
    super.initState();
    _carregar();
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

  void _carregar() {
    _domiciliosFuture = _domicilioDao.listarPorTerritorio(widget.territorioId);
  }

  void _ajustarZoom(double fator) {
    final matrizAtual = _controladorZoom.value.clone();
    setState(() {
      _controladorZoom.value = matrizAtual..scale(fator, fator, 1.0);
    });
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

  void _abrirMenuCasa(Domicilio d) {
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
      body: FutureBuilder<List<Domicilio>>(
        future: _domiciliosFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final domicilios = snapshot.data!;

          if (domicilios.isEmpty) {
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

          return Stack(
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
                            for (final d in domicilios)
                              if (d.posX != null && d.posY != null)
                                Positioned(
                                  left: d.posX! * largura,
                                  top: d.posY! * altura,
                                  child: FractionalTranslation(
                                    translation: const Offset(-0.5, -1.0),
                                    child: Transform.scale(
                                      scale: 1 / _escalaAtual,
                                      alignment: Alignment.bottomCenter,
                                      child: GestureDetector(
                                        onTap: () => _abrirMenuCasa(d),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on,
                                                color: Colors.teal, size: 36),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                boxShadow: const [
                                                  BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 2),
                                                ],
                                              ),
                                              child: Text(
                                                d.numero,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
          );
        },
      ),
    );
  }
}