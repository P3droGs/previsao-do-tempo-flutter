import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../armazenamento.dart';
import '../cptec_service.dart';
import '../models.dart';

class PrevisaoScreen extends StatefulWidget {
  final Cidade cidade;
  const PrevisaoScreen({super.key, required this.cidade});

  @override
  State<PrevisaoScreen> createState() => _PrevisaoScreenState();
}

class _PrevisaoScreenState extends State<PrevisaoScreen> {
  final _service = CptecService();

  Previsao? _previsao;
  bool _carregando = false;
  String? _erro;
  bool _doCache = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final id = widget.cidade.id;
    try {
      final xml = await _service.buscarPrevisaoXml(id);
      final previsao = CptecService.lerPrevisao(xml);
      if (previsao.dias.isNotEmpty) await Armazenamento.salvarPrevisao(id, xml);
      if (!mounted) return;
      setState(() {
        _previsao = previsao;
        _doCache = false;
      });
    } catch (e) {
      final mensagem = e is CptecException
          ? e.mensagem
          : 'Não foi possível carregar a previsão.';
      // Sem conexão: mostra a última previsão salva desta cidade, se houver.
      final salvo = await Armazenamento.previsaoSalva(id);
      Previsao? cache;
      try {
        if (salvo != null) cache = CptecService.lerPrevisao(salvo);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _erro = mensagem;
        if (cache != null) {
          _previsao = cache;
          _doCache = true;
        }
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cidade.nome} - ${widget.cidade.uf}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());

    final previsao = _previsao;
    if (previsao == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _erro ?? 'Nenhuma previsão disponível.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (previsao.dias.isEmpty) {
      return const Center(
        child: Text('Nenhuma previsão disponível para esta cidade.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_doCache)
          Card(
            color: Colors.amber.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('$_erro\nMostrando a última previsão salva.'),
            ),
          ),
        Text('Atualizado em: ${formatarData(previsao.atualizacao)}'),
        const SizedBox(height: 8),
        ...previsao.dias.map(_cardDia),
        const SizedBox(height: 16),
        const Text(
          'Temperaturas (°C)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: _grafico(previsao.dias)),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 10, color: Colors.red),
            Text(' Máxima   '),
            Icon(Icons.circle, size: 10, color: Colors.blue),
            Text(' Mínima'),
          ],
        ),
        const SizedBox(height: 16),
        const Center(child: Text('Fonte dos dados: CPTEC/INPE')),
      ],
    );
  }

  Widget _cardDia(PrevisaoDia dia) {
    String temp(int? t) => t == null ? '--' : '$t °C';
    return Card(
      child: ListTile(
        leading: Icon(iconeTempo(dia.tempo), size: 36),
        title: Text(formatarData(dia.data)),
        subtitle: Text(
          [
            descricaoTempo(dia.tempo),
            'Mín ${temp(dia.minima)} · Máx ${temp(dia.maxima)}',
            if (dia.iuv != null) 'Índice UV: ${dia.iuv}',
          ].join('\n'),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _grafico(List<PrevisaoDia> dias) {
    List<FlSpot> pontos(int? Function(PrevisaoDia) valor) => [
      for (var i = 0; i < dias.length; i++)
        if (valor(dias[i]) != null)
          FlSpot(i.toDouble(), valor(dias[i])!.toDouble()),
    ];

    LineChartBarData linha(List<FlSpot> spots, Color cor) => LineChartBarData(
      spots: spots,
      color: cor,
      barWidth: 3,
      dotData: const FlDotData(show: true),
    );

    // Eixo Y em múltiplos de 5, com folga acima e abaixo.
    final temps = [
      for (final d in dias) ...[d.minima, d.maxima],
    ].whereType<int>();
    final minY = temps.isEmpty
        ? 0.0
        : ((temps.reduce(min) - 1) / 5).floor() * 5.0;
    final maxY = temps.isEmpty
        ? 40.0
        : ((temps.reduce(max) + 1) / 5).ceil() * 5.0;

    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            linha(pontos((d) => d.maxima), Colors.red),
            linha(pontos((d) => d.minima), Colors.blue),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 5,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (valor, meta) {
                  final i = valor.toInt();
                  if (i < 0 || i >= dias.length || dias[i].data == null) {
                    return const SizedBox.shrink();
                  }
                  final d = dias[i].data!;
                  return Text('${d.day}/${d.month}');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
