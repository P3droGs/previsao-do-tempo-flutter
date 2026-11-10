import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'models.dart';

/// Erro com mensagem pronta para mostrar ao usuário.
class CptecException implements Exception {
  final String mensagem;
  CptecException(this.mensagem);

  @override
  String toString() => mensagem;
}

class CptecService {
  static const _base = 'https://servicos.cptec.inpe.br/XML';

  /// Faz o GET e devolve o XML como texto (o serviço responde em ISO-8859-1).
  Future<String> _get(Uri uri) async {
    try {
      final resposta = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resposta.statusCode != 200) {
        throw CptecException(
          'Serviço do CPTEC indisponível (código ${resposta.statusCode}).',
        );
      }
      return latin1.decode(resposta.bodyBytes);
    } on SocketException {
      throw CptecException('Sem conexão com a internet.');
    } on TimeoutException {
      throw CptecException('O serviço demorou para responder. Tente de novo.');
    } on http.ClientException {
      throw CptecException('Falha de conexão com o serviço do CPTEC.');
    }
  }

  Future<List<Cidade>> buscarCidades(String nome) async {
    final uri = Uri.parse('$_base/listaCidades')
        .replace(queryParameters: {'city': removerAcentos(nome)});
    final xml = await _get(uri);
    try {
      final doc = XmlDocument.parse(xml);
      _exigirRaiz(doc, 'cidades');
      return doc
          .findAllElements('cidade')
          .map((e) {
            return Cidade(
              id: _texto(e, 'id') ?? '',
              nome: _texto(e, 'nome') ?? 'Sem nome',
              uf: _texto(e, 'uf') ?? '--',
            );
          })
          .where((c) => c.id.isNotEmpty)
          .toList();
    } on XmlException {
      throw CptecException('Resposta inválida do serviço.');
    }
  }

  /// Previsão para 4 dias. Devolve o XML bruto (para guardar no cache).
  Future<String> buscarPrevisaoXml(String id) =>
      _get(Uri.parse('$_base/cidade/$id/previsao.xml'));

  static Previsao lerPrevisao(String xml) {
    try {
      final doc = XmlDocument.parse(xml);
      _exigirRaiz(doc, 'cidade');
      final dias = doc
          .findAllElements('previsao')
          .map(
            (e) => PrevisaoDia(
              data: DateTime.tryParse(_texto(e, 'dia') ?? ''),
              tempo: _texto(e, 'tempo'),
              minima: int.tryParse(_texto(e, 'minima') ?? ''),
              maxima: int.tryParse(_texto(e, 'maxima') ?? ''),
              iuv: double.tryParse(_texto(e, 'iuv') ?? ''),
            ),
          )
          // código inexistente vem com "null" em todos os campos
          .where((d) => d.data != null)
          .toList();
      return Previsao(
        atualizacao: DateTime.tryParse(_texto(doc, 'atualizacao') ?? ''),
        dias: dias,
      );
    } on XmlException {
      throw CptecException('Resposta inválida do serviço.');
    }
  }

  /// XML bem formado mas com outro conteúdo (ex.: página de erro) é inválido.
  static void _exigirRaiz(XmlDocument doc, String nome) {
    if (doc.rootElement.name.local != nome) {
      throw CptecException('Resposta inválida do serviço.');
    }
  }

  static String? _texto(XmlNode no, String tag) {
    final valor = no.findAllElements(tag).firstOrNull?.innerText.trim();
    if (valor == null || valor.isEmpty || valor == 'null') return null;
    return valor;
  }
}

/// Siglas das condições do tempo, conforme a documentação do CPTEC/INPE.
const condicoes = {
  'ec': 'Encoberto com Chuvas Isoladas',
  'ci': 'Chuvas Isoladas',
  'c': 'Chuva',
  'in': 'Instável',
  'pp': 'Possibilidade de Pancadas de Chuva',
  'cm': 'Chuva pela Manhã',
  'cn': 'Chuva à Noite',
  'pt': 'Pancadas de Chuva à Tarde',
  'pm': 'Pancadas de Chuva pela Manhã',
  'np': 'Nublado e Pancadas de Chuva',
  'pc': 'Pancadas de Chuva',
  'pn': 'Parcialmente Nublado',
  'cv': 'Chuvisco',
  'ch': 'Chuvoso',
  't': 'Tempestade',
  'ps': 'Predomínio de Sol',
  'e': 'Encoberto',
  'n': 'Nublado',
  'cl': 'Céu Claro',
  'nv': 'Nevoeiro',
  'g': 'Geada',
  'ne': 'Neve',
  'nd': 'Não Definido',
  'pnt': 'Pancadas de Chuva à Noite',
  'psc': 'Possibilidade de Chuva',
  'pcm': 'Possibilidade de Chuva pela Manhã',
  'pct': 'Possibilidade de Chuva à Tarde',
  'pcn': 'Possibilidade de Chuva à Noite',
  'npt': 'Nublado com Pancadas à Tarde',
  'npn': 'Nublado com Pancadas à Noite',
  'ncn': 'Nublado com Possibilidade de Chuva à Noite',
  'nct': 'Nublado com Possibilidade de Chuva à Tarde',
  'ncm': 'Nublado com Possibilidade de Chuva pela Manhã',
  'npm': 'Nublado com Pancadas pela Manhã',
  'npp': 'Nublado com Possibilidade de Chuva',
  'vn': 'Variação de Nebulosidade',
  'ct': 'Chuva à Tarde',
  'ppn': 'Possibilidade de Pancadas de Chuva à Noite',
  'ppt': 'Possibilidade de Pancadas de Chuva à Tarde',
  'ppm': 'Possibilidade de Pancadas de Chuva pela Manhã',
};

String descricaoTempo(String? sigla) =>
    condicoes[sigla] ?? 'Condição não informada';

IconData iconeTempo(String? sigla) {
  switch (sigla) {
    case 'cl':
    case 'ps':
      return Icons.wb_sunny;
    case 'pn':
    case 'vn':
      return Icons.wb_cloudy;
    case 'n':
    case 'e':
      return Icons.cloud;
    case 't':
      return Icons.thunderstorm;
    case 'nv':
      return Icons.foggy;
    case 'g':
    case 'ne':
      return Icons.ac_unit;
    case null:
    case 'nd':
      return Icons.help_outline;
    default:
      return Icons.water_drop; // demais siglas envolvem chuva
  }
}

/// A documentação pede o parâmetro city sem acentos.
String removerAcentos(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const para = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final buffer = StringBuffer();
  for (final c in texto.split('')) {
    final i = de.indexOf(c);
    buffer.write(i >= 0 ? para[i] : c);
  }
  return buffer.toString();
}

String formatarData(DateTime? data) {
  if (data == null) return '--';
  String doisDigitos(int n) => n.toString().padLeft(2, '0');
  return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year}';
}
