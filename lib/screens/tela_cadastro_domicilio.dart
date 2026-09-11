import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/domicilio.dart';
import '../database/domicilio_dao.dart';
import 'tela_cadastro_familia.dart';
import 'tela_selecionar_local_mapa.dart';

class TelaCadastroDomicilio extends StatefulWidget {
  final String territorioId;
  final Domicilio? domicilioParaEditar;

  const TelaCadastroDomicilio({
    super.key,
    required this.territorioId,
    this.domicilioParaEditar,
  });

  @override
  State<TelaCadastroDomicilio> createState() => _TelaCadastroDomicilioState();
}

class _TelaCadastroDomicilioState extends State<TelaCadastroDomicilio> {
  final _formKey = GlobalKey<FormState>();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _domicilioDao = DomicilioDao();

  bool _salvando = false;

  bool get _editando => widget.domicilioParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      final d = widget.domicilioParaEditar!;
      _ruaController.text = d.rua;
      _numeroController.text = d.numero;
      _bairroController.text = d.bairro;
      _complementoController.text = d.complemento ?? '';
    }
  }

   Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    if (_editando) {
      final domicilioAtualizado = Domicilio(
        id: widget.domicilioParaEditar!.id,
        territorioId: widget.domicilioParaEditar!.territorioId,
        rua: _ruaController.text.trim(),
        numero: _numeroController.text.trim(),
        bairro: _bairroController.text.trim(),
        complemento: _complementoController.text.trim().isEmpty
            ? null
            : _complementoController.text.trim(),
        posX: widget.domicilioParaEditar!.posX,
        posY: widget.domicilioParaEditar!.posY,
      );
      await _domicilioDao.atualizar(domicilioAtualizado);

      if (!mounted) return;
      setState(() => _salvando = false);
      Navigator.pop(context);
      return;
    }

    final domicilio = Domicilio(
      id: const Uuid().v4(),
      territorioId: widget.territorioId,
      rua: _ruaController.text.trim(),
      numero: _numeroController.text.trim(),
      bairro: _bairroController.text.trim(),
      complemento: _complementoController.text.trim().isEmpty
          ? null
          : _complementoController.text.trim(),
    );

    await _domicilioDao.inserir(domicilio);

    if (!mounted) return;

    // Pede para o agente indicar onde fica a casa no mapa antes de seguir
    final posicao = await Navigator.push<Offset>(
      context,
      MaterialPageRoute(builder: (_) => const TelaSelecionarLocalMapa()),
    );

    if (posicao != null) {
      await _domicilioDao.atualizarPosicao(domicilio.id, posicao.dx, posicao.dy);
    }

    if (!mounted) return;
    setState(() => _salvando = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroFamilia(domicilioId: domicilio.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar domicílio' : 'Novo domicílio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _ruaController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Rua'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a rua' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Número'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o número' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bairroController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o bairro' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _complementoController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Complemento (opcional)',
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const CircularProgressIndicator()
                      : Text(
                          _editando ? 'Salvar alterações' : 'Salvar e continuar',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}