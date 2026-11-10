class Cidade {
  final String id;
  final String nome;
  final String uf;

  Cidade({required this.id, required this.nome, required this.uf});

  Map<String, String> toJson() => {'id': id, 'nome': nome, 'uf': uf};

  factory Cidade.fromJson(Map<String, dynamic> json) =>
      Cidade(id: json['id'], nome: json['nome'], uf: json['uf']);
}

class PrevisaoDia {
  final DateTime? data;
  final String? tempo; // sigla da condição (ex.: "pn")
  final int? minima;
  final int? maxima;
  final double? iuv;

  PrevisaoDia({this.data, this.tempo, this.minima, this.maxima, this.iuv});
}

class Previsao {
  final DateTime? atualizacao;
  final List<PrevisaoDia> dias;

  Previsao({this.atualizacao, required this.dias});
}
