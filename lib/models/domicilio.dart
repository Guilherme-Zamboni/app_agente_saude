class Domicilio {
  final String id;
  final String territorioId;
  final String rua;
  final String numero;
  final String bairro;
  final String? complemento;
  final bool ativo;
  final double? posX; // posição no mapa (0.0 a 1.0), null = ainda não posicionado
  final double? posY;

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
  });

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
      ativo: map['ativo'] == 1,
      posX: map['pos_x'] as double?,
      posY: map['pos_y'] as double?,
    );
  }
}