class Morador {
  final String id;
  final String familiaId;
  final String nome;
  final String nomeDaMae;
  final DateTime dataNascimento;
  final String? cpf;
  final List<String> comorbidades;
  final bool gestante;
  final String? anotacoesAgente;
  final bool ativo;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  Morador({
    required this.id,
    required this.familiaId,
    required this.nome,
    required this.nomeDaMae,
    required this.dataNascimento,
    this.cpf,
    this.comorbidades = const [],
    this.gestante = false,
    this.anotacoesAgente,
    this.ativo = true,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'familia_id': familiaId,
      'nome': nome,
      'nome_da_mae': nomeDaMae,
      'data_nascimento': dataNascimento.toIso8601String(),
      'cpf': cpf,
      'comorbidades': comorbidades.join(','),
      'gestante': gestante ? 1 : 0,
      'anotacoes_agente': anotacoesAgente,
      'ativo': ativo ? 1 : 0,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  

  factory Morador.fromMap(Map<String, dynamic> map) {
    return Morador(
      id: map['id'],
      familiaId: map['familia_id'],
      nome: map['nome'],
      nomeDaMae: map['nome_da_mae'],
      dataNascimento: DateTime.parse(map['data_nascimento']),
      cpf: map['cpf'],
      comorbidades: (map['comorbidades'] as String).isEmpty
          ? []
          : (map['comorbidades'] as String).split(','),
      gestante: map['gestante'] == 1,
      anotacoesAgente: map['anotacoes_agente'],
      ativo: map['ativo'] == 1,
      criadoEm: DateTime.parse(map['criado_em']),
      atualizadoEm: DateTime.parse(map['atualizado_em']),
    );
  }
}