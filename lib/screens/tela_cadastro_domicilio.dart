import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/domicilio.dart';
import '../models/visita.dart';
import '../database/domicilio_dao.dart';
import '../database/visita_dao.dart';
import '../utils/texto.dart';
import '../widgets/dialogo_visita.dart';
import 'tela_cadastro_familia.dart';
import 'tela_selecionar_local_mapa.dart';

class TelaCadastroDomicilio extends StatefulWidget {
  final String territorioId;
  final Domicilio? domicilioParaEditar;
  final String? imagemMapa;
  final double? proporcaoMapa;

  const TelaCadastroDomicilio({
    super.key,
    required this.territorioId,
    this.domicilioParaEditar,
    this.imagemMapa,
    this.proporcaoMapa,
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

  // sugestões tiradas das casas já cadastradas na microárea
  List<String> _ruasSugeridas = [];
  List<String> _bairrosSugeridos = [];
  final Map<String, String> _bairroDaRua = {}; // rua normalizada -> bairro

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
    _carregarSugestoes();
  }

  Future<void> _carregarSugestoes() async {
    final lista = await _domicilioDao.sugestoesDeEndereco(widget.territorioId);

    // a lista vem das mais usadas para as menos usadas; a primeira grafia
    // de cada rua/bairro (ignorando acento e maiúscula) é a que prevalece
    final ruas = <String, String>{};
    final bairros = <String, String>{};
    final bairroDaRua = <String, String>{};

    for (final s in lista) {
      final rua = s.rua.trim();
      final bairro = s.bairro.trim();
      final chaveRua = normalizar(rua);
      final chaveBairro = normalizar(bairro);

      if (chaveRua.isNotEmpty) {
        ruas.putIfAbsent(chaveRua, () => rua);
        if (chaveBairro.isNotEmpty) {
          bairroDaRua.putIfAbsent(chaveRua, () => bairro);
        }
      }
      if (chaveBairro.isNotEmpty) {
        bairros.putIfAbsent(chaveBairro, () => bairro);
      }
    }

    if (!mounted) return;
    setState(() {
      _ruasSugeridas = ruas.values.toList();
      _bairrosSugeridos = bairros.values.toList();
      _bairroDaRua
        ..clear()
        ..addAll(bairroDaRua);
    });
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
    // 1) A localização vem primeiro: a casa só é salva se ela for marcada.
    //    Assim não sobra casa sem posição, que não aparece no mapa.
    final posicao = await Navigator.push<Offset?>(
      context,
      MaterialPageRoute(
        builder: (_) => TelaSelecionarLocalMapa(
          imagemMapa: widget.imagemMapa,
          proporcaoMapa: widget.proporcaoMapa,
          territorioId: widget.territorioId,
          enderecoNovaCasa:
              '${_ruaController.text.trim()}, ${_numeroController.text.trim()}',
        ),
      ),
    );

    if (!mounted) return;

    if (posicao == null) {
      // volta ao formulário com os dados preenchidos, nada foi salvo
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A casa não foi salva. Marque a localização no mapa para '
            'concluir o cadastro.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final domicilio = Domicilio(
      id: const Uuid().v4(),
      territorioId: widget.territorioId,
      rua: _ruaController.text.trim(),
      numero: _numeroController.text.trim(),
      bairro: _bairroController.text.trim(),
      complemento: _complemento,
      posX: posicao.dx,
      posY: posicao.dy,
    );

    await _domicilioDao.inserir(domicilio);

    if (!mounted) return;
    setState(() => _salvando = false);

    // 2) pergunta se encontrou moradores
    final escolha = await _perguntarSeEncontrouMoradores();
    if (!mounted) return;

    if (escolha == 'familia') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TelaCadastroFamilia(domicilioId: domicilio.id),
        ),
      );
      return;
    }

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
              _CampoComSugestoes(
                controller: _ruaController,
                rotulo: 'Rua',
                opcoes: _ruasSugeridas,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a rua' : null,
                aoSelecionar: (rua) {
                  // preenche o bairro só se ainda estiver vazio
                  if (_bairroController.text.trim().isEmpty) {
                    final bairro = _bairroDaRua[normalizar(rua)];
                    if (bairro != null) _bairroController.text = bairro;
                  }
                },
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
              _CampoComSugestoes(
                controller: _bairroController,
                rotulo: 'Bairro',
                opcoes: _bairrosSugeridos,
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

/// Campo de texto que oferece uma lista de opções já usadas, filtrada
/// enquanto se digita. A busca ignora maiúsculas e acentos.
class _CampoComSugestoes extends StatefulWidget {
  final TextEditingController controller;
  final String rotulo;
  final List<String> opcoes;
  final String? Function(String?)? validator;
  final ValueChanged<String>? aoSelecionar;

  const _CampoComSugestoes({
    required this.controller,
    required this.rotulo,
    required this.opcoes,
    this.validator,
    this.aoSelecionar,
  });

  @override
  State<_CampoComSugestoes> createState() => _CampoComSugestoesState();
}

class _CampoComSugestoesState extends State<_CampoComSugestoes> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  Iterable<String> _filtrar(TextEditingValue valor) {
    final busca = normalizar(valor.text);
    final lista = busca.isEmpty
        ? widget.opcoes
        : widget.opcoes.where((o) => normalizar(o).contains(busca));
    return lista.take(8);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) => RawAutocomplete<String>(
        // a chave refaz o campo quando a lista de sugestões termina de
        // carregar, senão ele continuaria com a lista vazia do início
        key: ValueKey(widget.opcoes.length),
        textEditingController: widget.controller,
        focusNode: _foco,
        optionsBuilder: _filtrar,
        onSelected: (valor) => widget.aoSelecionar?.call(valor),
        fieldViewBuilder: (context, controller, foco, aoEnviar) =>
            TextFormField(
          controller: controller,
          focusNode: foco,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: widget.rotulo,
            suffixIcon: widget.opcoes.isEmpty
                ? null
                : const Icon(Icons.arrow_drop_down),
          ),
          validator: widget.validator,
        ),
        optionsViewBuilder: (context, aoSelecionar, opcoes) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 220,
                maxWidth: restricoes.maxWidth,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opcoes.length,
                itemBuilder: (context, indice) {
                  final opcao = opcoes.elementAt(indice);
                  return ListTile(
                    dense: true,
                    title: Text(opcao, style: const TextStyle(fontSize: 16)),
                    onTap: () => aoSelecionar(opcao),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}