import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/morador.dart';
import '../models/familia.dart';
import '../database/morador_dao.dart';
import '../database/familia_dao.dart';

const List<String> comorbidadesDisponiveis = [
  'hipertensao',
  'diabetes',
  'obesidade',
  'cardiopatia',
  'problema_respiratorio',
];

const Map<String, String> comorbidadesLabels = {
  'hipertensao': 'Hipertensão',
  'diabetes': 'Diabetes',
  'obesidade': 'Obesidade',
  'cardiopatia': 'Cardiopatia',
  'problema_respiratorio': 'Problema respiratório',
};

class TelaCadastroMorador extends StatefulWidget {
  // domicilioId só é necessário ao CRIAR um morador novo (a família é criada
  // junto). Em modo de edição, não é usado.
  final String? domicilioId;
  final String? observacoesFamilia;
  final Morador? moradorParaEditar;

  const TelaCadastroMorador({
    super.key,
    this.domicilioId,
    this.observacoesFamilia,
    this.moradorParaEditar,
  });

  @override
  State<TelaCadastroMorador> createState() => _TelaCadastroMoradorState();
}

class _TelaCadastroMoradorState extends State<TelaCadastroMorador> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _nomeDaMaeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _anotacoesController = TextEditingController();
  final _moradorDao = MoradorDao();
  final _familiaDao = FamiliaDao();

  DateTime? _dataNascimento;
  bool _gestante = false;
  final Set<String> _comorbidadesSelecionadas = {};
  bool _salvando = false;

  String? _familiaId;

  bool get _editando => widget.moradorParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      final m = widget.moradorParaEditar!;
      _familiaId = m.familiaId;
      _nomeController.text = m.nome;
      _nomeDaMaeController.text = m.nomeDaMae;
      _cpfController.text = m.cpf ?? '';
      _anotacoesController.text = m.anotacoesAgente ?? '';
      _dataNascimento = m.dataNascimento;
      _gestante = m.gestante;
      _comorbidadesSelecionadas.addAll(m.comorbidades);
    }
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (data != null) setState(() => _dataNascimento = data);
  }

  Future<void> _salvar({bool cadastrarOutro = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataNascimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de nascimento')),
      );
      return;
    }

    setState(() => _salvando = true);

    // --- Modo edição: atualiza o morador existente e volta ---
    if (_editando) {
      final atualizado = Morador(
        id: widget.moradorParaEditar!.id,
        familiaId: widget.moradorParaEditar!.familiaId,
        nome: _nomeController.text.trim(),
        nomeDaMae: _nomeDaMaeController.text.trim(),
        dataNascimento: _dataNascimento!,
        cpf: _cpfController.text.trim().isEmpty ? null : _cpfController.text.trim(),
        comorbidades: _comorbidadesSelecionadas.toList(),
        gestante: _gestante,
        anotacoesAgente: _anotacoesController.text.trim().isEmpty
            ? null
            : _anotacoesController.text.trim(),
        ativo: widget.moradorParaEditar!.ativo,
        criadoEm: widget.moradorParaEditar!.criadoEm,
        atualizadoEm: DateTime.now(),
      );

      await _moradorDao.atualizar(atualizado);

      if (!mounted) return;
      setState(() => _salvando = false);
      Navigator.pop(context);
      return;
    }

    // --- Modo cadastro: cria a família (se ainda não existir) + o morador ---
    if (_familiaId == null) {
      final novaFamilia = Familia(
        id: const Uuid().v4(),
        domicilioId: widget.domicilioId!,
        observacoes: widget.observacoesFamilia,
      );
      await _familiaDao.inserir(novaFamilia);
      _familiaId = novaFamilia.id;
    }

    final duplicado = await _moradorDao.verificarDuplicidade(
      nome: _nomeController.text,
      nomeDaMae: _nomeDaMaeController.text,
      dataNascimento: _dataNascimento!,
    );

    if (duplicado && mounted) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Possível duplicidade'),
          content: const Text(
            'Já existe um morador cadastrado com esse nome, nome da mãe '
            'e data de nascimento. Deseja cadastrar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cadastrar mesmo assim'),
            ),
          ],
        ),
      );
      if (continuar != true) {
        setState(() => _salvando = false);
        return;
      }
    }

    final agora = DateTime.now();
    final morador = Morador(
      id: const Uuid().v4(),
      familiaId: _familiaId!,
      nome: _nomeController.text.trim(),
      nomeDaMae: _nomeDaMaeController.text.trim(),
      dataNascimento: _dataNascimento!,
      cpf: _cpfController.text.trim().isEmpty ? null : _cpfController.text.trim(),
      comorbidades: _comorbidadesSelecionadas.toList(),
      gestante: _gestante,
      anotacoesAgente: _anotacoesController.text.trim().isEmpty
          ? null
          : _anotacoesController.text.trim(),
      criadoEm: agora,
      atualizadoEm: agora,
    );

    await _moradorDao.inserir(morador);

    if (!mounted) return;
    setState(() => _salvando = false);

    if (cadastrarOutro) {
      _formKey.currentState!.reset();
      _nomeController.clear();
      _nomeDaMaeController.clear();
      _cpfController.clear();
      _anotacoesController.clear();
      setState(() {
        _dataNascimento = null;
        _gestante = false;
        _comorbidadesSelecionadas.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Morador cadastrado! Adicione o próximo.')),
      );
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar morador' : 'Cadastro de morador'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeDaMaeController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Nome da mãe'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe o nome da mãe'
                    : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dataNascimento == null
                      ? 'Selecionar data de nascimento'
                      : 'Nascimento: ${_dataNascimento!.day.toString().padLeft(2, '0')}/'
                        '${_dataNascimento!.month.toString().padLeft(2, '0')}/'
                        '${_dataNascimento!.year}',
                  style: const TextStyle(fontSize: 18),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selecionarData,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cpfController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'CPF (opcional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              const Text('Comorbidades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: comorbidadesDisponiveis.map((c) {
                  final selecionado = _comorbidadesSelecionadas.contains(c);
                  return FilterChip(
                    label: Text(comorbidadesLabels[c]!),
                    selected: selecionado,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _comorbidadesSelecionadas.add(c);
                        } else {
                          _comorbidadesSelecionadas.remove(c);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gestante', style: TextStyle(fontSize: 18)),
                value: _gestante,
                onChanged: (v) => setState(() => _gestante = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _anotacoesController,
                style: const TextStyle(fontSize: 18),
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Anotações (opcional)'),
              ),
              const SizedBox(height: 32),
              if (!_editando) ...[
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _salvando ? null : () => _salvar(cadastrarOutro: true),
                    child: const Text('Salvar e cadastrar outro morador',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _salvando ? null : () => _salvar(),
                  child: _salvando
                      ? const CircularProgressIndicator()
                      : Text(
                          _editando ? 'Salvar alterações' : 'Salvar e concluir',
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