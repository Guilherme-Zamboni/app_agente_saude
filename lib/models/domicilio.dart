class Domicilio {
  final String id;
  final String territorioId;
  final String rua;
  final String numero;
  final String bairro;
  final String? complemento;
  final bool ativo;

  Domicilio({
    required this.id,
    required this.territorioId,
    required this.rua,
    required this.numero,
    required this.bairro,
    this.complemento,
    this.ativo = true,
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
    );
  }
}