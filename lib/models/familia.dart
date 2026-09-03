class Familia {
  final String id;
  final String domicilioId;
  final String? observacoes;
  final bool ativo;

  Familia({
    required this.id,
    required this.domicilioId,
    this.observacoes,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'domicilio_id': domicilioId,
      'observacoes': observacoes,
      'ativo': ativo ? 1 : 0,
    };
  }

  factory Familia.fromMap(Map<String, dynamic> map) {
    return Familia(
      id: map['id'],
      domicilioId: map['domicilio_id'],
      observacoes: map['observacoes'],
      ativo: map['ativo'] == 1,
    );
  }
}