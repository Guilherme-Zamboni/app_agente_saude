class Visita {
  final String id;
  final String familiaId;
  final String? moradorId;
  final DateTime dataVisita;
  final String? observacoes;
  final bool ativo;
  final DateTime atualizadoEm;
  final bool sincronizado;

  Visita({
    required this.id,
    required this.familiaId,
    this.moradorId,
    required this.dataVisita,
    this.observacoes,
    this.ativo = true,
    DateTime? atualizadoEm,
    this.sincronizado = false,
  }) : atualizadoEm = atualizadoEm ?? DateTime.now();

  bool get individual => moradorId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'familia_id': familiaId,
      'morador_id': moradorId,
      'data_visita': dataVisita.toIso8601String(),
      'observacoes': observacoes,
      'ativo': ativo ? 1 : 0,
      'atualizado_em': atualizadoEm.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'familia_id': familiaId,
      'morador_id': moradorId,
      'data_visita': dataVisita.toIso8601String(),
      'observacoes': observacoes,
      'ativo': ativo,
    };
  }

  factory Visita.fromMap(Map<String, dynamic> map) {
    return Visita(
      id: map['id'],
      familiaId: map['familia_id'],
      moradorId: map['morador_id'],
      dataVisita: DateTime.parse(map['data_visita']),
      observacoes: map['observacoes'],
      ativo: map['ativo'] == null || map['ativo'] == 1 || map['ativo'] == true,
      atualizadoEm: map['atualizado_em'] == null || map['atualizado_em'] == ''
          ? DateTime.now()
          : DateTime.parse(map['atualizado_em']),
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
    );
  }
}