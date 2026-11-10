import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persistência local com shared_preferences:
/// - a última cidade selecionada (JSON);
/// - o último XML de previsão de cada cidade (usado quando não há conexão).
class Armazenamento {
  static const _chaveCidade = 'ultima_cidade';
  static String _chavePrevisao(String id) => 'previsao_$id';

  static Future<void> salvarCidade(Cidade cidade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveCidade, jsonEncode(cidade.toJson()));
  }

  static Future<Cidade?> ultimaCidade() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_chaveCidade);
    if (json == null) return null;
    try {
      return Cidade.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  static Future<void> salvarPrevisao(String id, String xml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chavePrevisao(id), xml);
  }

  static Future<String?> previsaoSalva(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chavePrevisao(id));
  }
}
