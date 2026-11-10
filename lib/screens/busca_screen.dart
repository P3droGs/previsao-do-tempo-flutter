import 'package:flutter/material.dart';

import '../armazenamento.dart';
import '../cptec_service.dart';
import '../models.dart';
import 'previsao_screen.dart';

class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key});

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  final _controller = TextEditingController();
  final _service = CptecService();

  List<Cidade>? _cidades;
  Cidade? _ultima;
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    Armazenamento.ultimaCidade().then((c) => setState(() => _ultima = c));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
      _cidades = null;
    });
    try {
      final cidades = await _service.buscarCidades(nome);
      setState(() => _cidades = cidades);
    } catch (e) {
      setState(
        () => _erro = e is CptecException
            ? e.mensagem
            : 'Não foi possível buscar as cidades.',
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _abrir(Cidade cidade) async {
    await Armazenamento.salvarCidade(cidade);
    setState(() => _ultima = cidade);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrevisaoScreen(cidade: cidade)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Previsão do Tempo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                labelText: 'Nome da cidade',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscar,
                ),
              ),
            ),
          ),
          if (_ultima != null && _cidades == null && !_carregando)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text('${_ultima!.nome} - ${_ultima!.uf}'),
              subtitle: const Text('Última cidade consultada'),
              onTap: () => _abrir(_ultima!),
            ),
          Expanded(child: _resultado()),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Fonte dos dados: CPTEC/INPE'),
          ),
        ],
      ),
    );
  }

  Widget _resultado() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(child: Text(_erro!, textAlign: TextAlign.center));
    }
    if (_cidades == null) return const SizedBox.shrink();
    if (_cidades!.isEmpty) {
      return const Center(child: Text('Nenhuma cidade encontrada.'));
    }
    return ListView.builder(
      itemCount: _cidades!.length,
      itemBuilder: (_, i) {
        final c = _cidades![i];
        return ListTile(
          leading: const Icon(Icons.location_city),
          title: Text(c.nome),
          subtitle: Text(c.uf),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _abrir(c),
        );
      },
    );
  }
}
