class Domicilio {
  final String id;
  final String territorioId;
  final String rua;
  final String numero;
  final String bairro;
  final String? complemento;
  final bool ativo;
  final double? posX;
  final double? posY;
  final DateTime atualizadoEm;
  final bool sincronizado;

  Domicilio({
    required this.id,
    required this.territorioId,
    required this.rua,
    required this.numero,
    required this.bairro,
    this.complemento,
    this.ativo = true,
    this.posX,
    this.posY,
    DateTime? atualizadoEm,
    this.sincronizado = false,
  }) : atualizadoEm = atualizadoEm ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'territorio_id': territorioId,
      'rua': rua,
      'numero': numero,
      'bairro': bairro,
      'complemento': complemento,
      'ativo': ativo ? 1 : 0,
      'pos_x': posX,
      'pos_y': posY,
      'atualizado_em': atualizadoEm.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  // Formato usado ao enviar para o Supabase (sem o campo de controle local)
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'territorio_id': territorioId,
      'rua': rua,
      'numero': numero,
      'bairro': bairro,
      'complemento': complemento,
      'ativo': ativo,
      'pos_x': posX,
      'pos_y': posY,
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  factory Domicilio.fromMap(Map<String, dynamic> map) {
    return Domicilio(
      id: map['id'],
      territorioId: map['territorio_id'],
      rua: map['rua'],
      numero: map['numero'],
      bairro: map['bairro'],
      complemento: map['complemento'],
      ativo: map['ativo'] == 1 || map['ativo'] == true,
      posX: (map['pos_x'] as num?)?.toDouble(),
      posY: (map['pos_y'] as num?)?.toDouble(),
      atualizadoEm: map['atualizado_em'] == null || map['atualizado_em'] == ''
          ? DateTime.now()
          : DateTime.parse(map['atualizado_em']),
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
    );
  }
}