import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/domicilio.dart';
import '../models/visita.dart';
import '../database/domicilio_dao.dart';
import '../database/visita_dao.dart';
import '../widgets/dialogo_visita.dart';
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
  final _visitaDao = VisitaDao();

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

  String? get _complemento => _complementoController.text.trim().isEmpty
      ? null
      : _complementoController.text.trim();

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    // --- Modo edição: só atualiza o endereço ---
    if (_editando) {
      final original = widget.domicilioParaEditar!;
      await _domicilioDao.atualizar(Domicilio(
        id: original.id,
        territorioId: original.territorioId,
        rua: _ruaController.text.trim(),
        numero: _numeroController.text.trim(),
        bairro: _bairroController.text.trim(),
        complemento: _complemento,
        posX: original.posX,
        posY: original.posY,
        criadoEm: original.criadoEm,
      ));

      if (!mounted) return;
      setState(() => _salvando = false);
      Navigator.pop(context);
      return;
    }

    // --- Modo cadastro ---
    final domicilio = Domicilio(
      id: const Uuid().v4(),
      territorioId: widget.territorioId,
      rua: _ruaController.text.trim(),
      numero: _numeroController.text.trim(),
      bairro: _bairroController.text.trim(),
      complemento: _complemento,
    );

    await _domicilioDao.inserir(domicilio);

    if (!mounted) return;

    // 1) marca a posição da casa no mapa
    final posicao = await Navigator.push<Offset?>(
      context,
      MaterialPageRoute(builder: (_) => const TelaSelecionarLocalMapa()),
    );

    if (posicao != null) {
      await _domicilioDao.atualizarPosicao(domicilio.id, posicao.dx, posicao.dy);
    }

    if (!mounted) return;
    setState(() => _salvando = false);

    // 2) pergunta se encontrou moradores
    final escolha = await _perguntarSeEncontrouMoradores();
    if (!mounted) return;

    if (escolha == 'familia') {
      // segue o fluxo normal de cadastro da família
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TelaCadastroFamilia(domicilioId: domicilio.id),
        ),
      );
      return;
    }

    // 'ninguem' ou fechou a escolha: a casa fica como não cadastrada
    final mensageiro = ScaffoldMessenger.of(context);

    if (escolha == 'ninguem') {
      final dados = await mostrarDialogoVisita(
        context,
        titulo: 'Registrar tentativa de visita',
        subtitulo: 'A casa foi salva como não cadastrada. '
            'Toque em Cancelar se não quiser registrar a visita agora.',
        permitirRealizada: false,
        resultadoInicial: 'ausente',
      );

      if (dados != null) {
        await _visitaDao.inserir(Visita(
          id: const Uuid().v4(),
          domicilioId: domicilio.id,
          dataVisita: DateTime.now(),
          resultado: dados.resultado,
          observacoes: dados.observacoes,
        ));
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    mensageiro.showSnackBar(
      const SnackBar(content: Text('Casa salva como não cadastrada')),
    );
  }

  /// Retorna 'familia', 'ninguem' ou null (se o agente fechar a tela).
  Future<String?> _perguntarSeEncontrouMoradores() {
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Encontrou moradores nesta casa?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _opcaoGrande(
                context,
                valor: 'familia',
                icone: Icons.family_restroom,
                cor: Colors.teal,
                titulo: 'Sim, cadastrar família',
                descricao: 'Registrar a família e os moradores agora',
              ),
              const SizedBox(height: 12),
              _opcaoGrande(
                context,
                valor: 'ninguem',
                icone: Icons.house_outlined,
                cor: Colors.purple,
                titulo: 'Não, ninguém em casa',
                descricao: 'Salvar como casa não cadastrada e registrar a '
                    'tentativa de visita',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcaoGrande(
    BuildContext context, {
    required String valor,
    required IconData icone,
    required Color cor,
    required String titulo,
    required String descricao,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(context, valor),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          border: Border.all(color: cor, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(descricao,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
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
                keyboardType: TextInputType.number,
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