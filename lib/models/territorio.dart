class Territorio {
  final String id;
  final String nome;
  final String agenteId;

  Territorio({
    required this.id,
    required this.nome,
    required this.agenteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'agente_id': agenteId,
    };
  }

  factory Territorio.fromMap(Map<String, dynamic> map) {
    return Territorio(
      id: map['id'],
      nome: map['nome'],
      agenteId: map['agente_id'],
    );
  }
}