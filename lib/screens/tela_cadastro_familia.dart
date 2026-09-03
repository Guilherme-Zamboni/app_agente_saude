import 'package:flutter/material.dart';
import '../models/familia.dart';
import '../database/familia_dao.dart';
import 'tela_cadastro_morador.dart';

class TelaCadastroFamilia extends StatefulWidget {
  final String domicilioId;
  final Familia? familiaParaEditar;

  const TelaCadastroFamilia({
    super.key,
    required this.domicilioId,
    this.familiaParaEditar,
  });

  @override
  State<TelaCadastroFamilia> createState() => _TelaCadastroFamiliaState();
}

class _TelaCadastroFamiliaState extends State<TelaCadastroFamilia> {
  final _observacoesController = TextEditingController();
  final _familiaDao = FamiliaDao();
  bool _salvando = false;

  bool get _editando => widget.familiaParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _observacoesController.text = widget.familiaParaEditar!.observacoes ?? '';
    }
  }

  Future<void> _salvar() async {
    if (_editando) {
      setState(() => _salvando = true);

      final familiaAtualizada = Familia(
        id: widget.familiaParaEditar!.id,
        domicilioId: widget.familiaParaEditar!.domicilioId,
        observacoes: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
      );
      await _familiaDao.atualizar(familiaAtualizada);

      if (!mounted) return;
      setState(() => _salvando = false);
      Navigator.pop(context);
      return;
    }

    // A família só é gravada no banco quando o primeiro morador for salvo,
    // evitando famílias vazias caso o agente saia do fluxo no meio do caminho.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCadastroMorador(
          domicilioId: widget.domicilioId,
          observacoesFamilia: _observacoesController.text.trim().isEmpty
              ? null
              : _observacoesController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar família' : 'Nova família')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            if (!_editando)
              const Text(
                'Você pode adicionar uma observação geral sobre a família '
                '(opcional) e depois cadastrar os moradores.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _observacoesController,
              style: const TextStyle(fontSize: 18),
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Observações (opcional)'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const CircularProgressIndicator()
                    : Text(
                        _editando
                            ? 'Salvar alterações'
                            : 'Continuar para cadastro de morador',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}