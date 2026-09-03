class Visita {
  final String id;
  final String familiaId;
  final String? moradorId; // null = visita geral da família; preenchido = visita extra individual
  final DateTime dataVisita;
  final String? observacoes;

  Visita({
    required this.id,
    required this.familiaId,
    this.moradorId,
    required this.dataVisita,
    this.observacoes,
  });

  bool get individual => moradorId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'familia_id': familiaId,
      'morador_id': moradorId,
      'data_visita': dataVisita.toIso8601String(),
      'observacoes': observacoes,
    };
  }

  factory Visita.fromMap(Map<String, dynamic> map) {
    return Visita(
      id: map['id'],
      familiaId: map['familia_id'],
      moradorId: map['morador_id'],
      dataVisita: DateTime.parse(map['data_visita']),
      observacoes: map['observacoes'],
    );
  }
}