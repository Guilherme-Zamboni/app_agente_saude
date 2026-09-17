import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class BarraSincronizacao extends StatefulWidget {
  final String territorioId;
  final VoidCallback aoSincronizar;

  const BarraSincronizacao({
    super.key,
    required this.territorioId,
    required this.aoSincronizar,
  });

  @override
  State<BarraSincronizacao> createState() => BarraSincronizacaoState();
}

class BarraSincronizacaoState extends State<BarraSincronizacao> {
  int _pendentes = 0;
  DateTime? _ultimaSync;
  bool _sincronizando = false;
  Timer? _timer;

  // evita que a sincronização automática dispare a cada reconstrução da tela
  static bool _jaSincronizouNestaSessao = false;

  @override
  void initState() {
    super.initState();
    _atualizarStatus();

    if (!_jaSincronizouNestaSessao) {
      _jaSincronizouNestaSessao = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => sincronizar(silencioso: true));
    }

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
        _atualizarStatus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _atualizarStatus() async {
    final pendentes = await SyncService.pendentes();
    final ultima = await SyncService.ultimaSincronizacao();
    if (!mounted) return;
    setState(() {
      _pendentes = pendentes;
      _ultimaSync = ultima;
    });
  }

  /// Permite que a tela peça uma atualização do contador de pendências.
  Future<void> atualizarStatusExterno() => _atualizarStatus();

  Future<void> sincronizar({bool silencioso = false}) async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);

    final resultado = await SyncService.sincronizar(widget.territorioId);

    if (!mounted) return;
    setState(() => _sincronizando = false);
    await _atualizarStatus();

    widget.aoSincronizar();

    if (!mounted) return;

    if (resultado.sucesso) {
      if (!silencioso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sincronizado: ${resultado.enviados} enviado(s), '
              '${resultado.recebidos} recebido(s)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (!silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.erro ?? 'Falha na sincronização'),
          backgroundColor: Colors.orange[800],
        ),
      );
    }
  }

  String get _textoStatus {
    if (_sincronizando) return 'Sincronizando...';
    if (_pendentes > 0) return '$_pendentes registro(s) aguardando envio';
    if (_ultimaSync == null) return 'Ainda não sincronizado';

    final minutos = DateTime.now().difference(_ultimaSync!).inMinutes;
    if (minutos < 1) return 'Tudo sincronizado agora';
    if (minutos < 60) return 'Sincronizado há $minutos min';
    final horas = minutos ~/ 60;
    if (horas < 24) return 'Sincronizado há ${horas}h';
    return 'Sincronizado há ${horas ~/ 24} dia(s)';
  }

  @override
  Widget build(BuildContext context) {
    final temPendencia = _pendentes > 0;
    final cor = _sincronizando
        ? Colors.blue[50]
        : temPendencia
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE8F5E9);

    return Material(
      color: cor,
      child: InkWell(
        onTap: _sincronizando ? null : () => sincronizar(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (_sincronizando)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  temPendencia
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined,
                  size: 18,
                  color: temPendencia ? Colors.orange[800] : Colors.green[700],
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _textoStatus,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (!_sincronizando)
                const Icon(Icons.refresh, size: 18, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}