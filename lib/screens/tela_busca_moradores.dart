import 'package:flutter/material.dart';
import '../models/morador.dart';
import '../database/morador_dao.dart';
import 'tela_ficha_morador.dart';

class TelaBuscaMoradores extends StatefulWidget {
  const TelaBuscaMoradores({super.key});

  @override
  State<TelaBuscaMoradores> createState() => _TelaBuscaMoradoresState();
}

class _TelaBuscaMoradoresState extends State<TelaBuscaMoradores> {
  final _moradorDao = MoradorDao();

  final _nomeController = TextEditingController();
  final _nomeDaMaeController = TextEditingController();
  final _ruaController = TextEditingController();
  final _bairroController = TextEditingController();
  DateTime? _dataNascimento;

  List<Morador> _resultados = [];
  bool _buscando = false;
  bool _jaBuscou = false;

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (data != null) setState(() => _dataNascimento = data);
  }

  bool get _temFiltroPorEndereco =>
      _ruaController.text.trim().isNotEmpty ||
      _bairroController.text.trim().isNotEmpty;

  bool get _temFiltroPorDados =>
      _nomeController.text.trim().isNotEmpty ||
      _nomeDaMaeController.text.trim().isNotEmpty ||
      _dataNascimento != null;

  Future<void> _buscar() async {
    if (!_temFiltroPorEndereco && !_temFiltroPorDados) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha ao menos um campo para buscar')),
      );
      return;
    }

    setState(() {
      _buscando = true;
      _jaBuscou = true;
    });

    List<Morador> resultado;

    if (_temFiltroPorEndereco) {
      // Busca por endereço (junta com nome/mãe/nascimento se preenchidos,
      // filtrando o resultado depois em memória, já que são tabelas diferentes)
      resultado = await _moradorDao.buscarPorEndereco(
        rua: _ruaController.text.trim().isEmpty ? null : _ruaController.text.trim(),
        bairro: _bairroController.text.trim().isEmpty ? null : _bairroController.text.trim(),
      );

      if (_temFiltroPorDados) {
        final nome = _nomeController.text.trim().toLowerCase();
        final nomeDaMae = _nomeDaMaeController.text.trim().toLowerCase();
        resultado = resultado.where((m) {
          final bateNome = nome.isEmpty || m.nome.toLowerCase().contains(nome);
          final bateMae = nomeDaMae.isEmpty ||
              m.nomeDaMae.toLowerCase().contains(nomeDaMae);
          final bateData = _dataNascimento == null ||
              m.dataNascimento.year == _dataNascimento!.year &&
                  m.dataNascimento.month == _dataNascimento!.month &&
                  m.dataNascimento.day == _dataNascimento!.day;
          return bateNome && bateMae && bateData;
        }).toList();
      }
    } else {
      resultado = await _moradorDao.buscar(
        nome: _nomeController.text.trim().isEmpty ? null : _nomeController.text.trim(),
        nomeDaMae: _nomeDaMaeController.text.trim().isEmpty
            ? null
            : _nomeDaMaeController.text.trim(),
        dataNascimento: _dataNascimento,
      );
    }

    if (!mounted) return;
    setState(() {
      _resultados = resultado;
      _buscando = false;
    });
  }

  void _limparFiltros() {
    _nomeController.clear();
    _nomeDaMaeController.clear();
    _ruaController.clear();
    _bairroController.clear();
    setState(() {
      _dataNascimento = null;
      _resultados = [];
      _jaBuscou = false;
    });
  }

  int _calcularIdade(DateTime nascimento) {
    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    return idade;
  }

    void _abrirFicha(Morador m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaFichaMorador(morador: m)),
    ).then((_) => setState(() {})); // atualiza a lista ao voltar (nome pode ter mudado)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar morador'),
        actions: [
          IconButton(
            onPressed: _limparFiltros,
            icon: const Icon(Icons.clear),
            tooltip: 'Limpar filtros',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nomeController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Nome do morador',
                    prefixIcon: Icon(Icons.person_search),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nomeDaMaeController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Nome da mãe',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _dataNascimento == null
                        ? 'Data de nascimento (opcional)'
                        : '${_dataNascimento!.day.toString().padLeft(2, '0')}/'
                          '${_dataNascimento!.month.toString().padLeft(2, '0')}/'
                          '${_dataNascimento!.year}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  trailing: _dataNascimento != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _dataNascimento = null),
                        )
                      : null,
                  onTap: _selecionarData,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ruaController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(labelText: 'Rua'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bairroController,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(labelText: 'Bairro'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _buscando ? null : _buscar,
                    icon: const Icon(Icons.search),
                    label: Text(_buscando ? 'Buscando...' : 'Buscar',
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !_jaBuscou
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Preencha algum filtro acima e toque em Buscar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black45),
                      ),
                    ),
                  )
                : _resultados.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum morador encontrado com esses filtros.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black45),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _resultados.length,
                        itemBuilder: (context, index) {
                          final m = _resultados[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(m.nome, style: const TextStyle(fontSize: 17)),
                            subtitle: Text(
                              '${_calcularIdade(m.dataNascimento)} anos'
                              '${m.gestante ? ' • Gestante' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _abrirFicha(m),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}