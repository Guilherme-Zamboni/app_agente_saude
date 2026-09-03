import 'package:flutter/material.dart';
import '../models/domicilio.dart';
import '../database/domicilio_dao.dart';
import 'tela_cadastro_domicilio.dart';
import 'tela_detalhe_domicilio.dart';
import 'tela_busca_moradores.dart';
import 'tela_estatisticas.dart';

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

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _domiciliosFuture = _domicilioDao.listarPorTerritorio(widget.territorioId);
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

  Future<void> _abrirDetalhe(Domicilio domicilio) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaDetalheDomicilio(domicilio: domicilio),
      ),
    );
    setState(_carregar);
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: domicilios.length,
            itemBuilder: (context, index) {
              final d = domicilios[index];
                            return _CartaoDomicilio(
                domicilio: d,
                onTap: () => _abrirDetalhe(d),
                onEditar: () => _abrirEdicao(d),
                onExcluir: () => _confirmarExclusao(d),
              );
            },
          );
        },
      ),
    );
  }
}

class _CartaoDomicilio extends StatelessWidget {
  final Domicilio domicilio;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const _CartaoDomicilio({
    required this.domicilio,
    required this.onTap,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home, size: 40, color: Colors.teal),
                  const SizedBox(height: 12),
                  Text(
                    '${domicilio.rua}, ${domicilio.numero}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    domicilio.bairro,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: InkWell(
              onTap: onEditar,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.edit_outlined, size: 20, color: Colors.black45),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onExcluir,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline, size: 20, color: Colors.black45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}