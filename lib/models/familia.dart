class Familia {
  final String id;
  final String domicilioId;
  final String? observacoes;
  final bool ativo;
  final DateTime atualizadoEm;
  final bool sincronizado;

  Familia({
    required this.id,
    required this.domicilioId,
    this.observacoes,
    this.ativo = true,
    DateTime? atualizadoEm,
    this.sincronizado = false,
  }) : atualizadoEm = atualizadoEm ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'domicilio_id': domicilioId,
      'observacoes': observacoes,
      'ativo': ativo ? 1 : 0,
      'atualizado_em': atualizadoEm.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'domicilio_id': domicilioId,
      'observacoes': observacoes,
      'ativo': ativo,
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  factory Familia.fromMap(Map<String, dynamic> map) {
    return Familia(
      id: map['id'],
      domicilioId: map['domicilio_id'],
      observacoes: map['observacoes'],
      ativo: map['ativo'] == 1 || map['ativo'] == true,
      atualizadoEm: map['atualizado_em'] == null || map['atualizado_em'] == ''
          ? DateTime.now()
          : DateTime.parse(map['atualizado_em']),
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
    );
  }
}