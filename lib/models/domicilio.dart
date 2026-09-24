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
  final DateTime criadoEm;
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
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    this.sincronizado = false,
  })  : criadoEm = criadoEm ?? DateTime.now(),
        atualizadoEm = atualizadoEm ?? DateTime.now();

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
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

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
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  static DateTime? _data(dynamic valor) {
    if (valor == null) return null;
    final texto = valor.toString();
    if (texto.isEmpty) return null;
    return DateTime.tryParse(texto);
  }

  factory Domicilio.fromMap(Map<String, dynamic> map) {
    final atualizado = _data(map['atualizado_em']);
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
      criadoEm: _data(map['criado_em']) ?? atualizado,
      atualizadoEm: atualizado,
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
    );
  }
}