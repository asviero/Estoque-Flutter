class Bebida {
  final String id;
  final String nome;
  int quantidade;

  Bebida({
    required this.id,
    required this.nome,
    this.quantidade = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
    };
  }

  factory Bebida.fromMap(Map<String, dynamic> map) {
    return Bebida(
      id: map['id'],
      nome: map['nome'],
      quantidade: map['quantidade'] ?? 0,
    );
  }
}