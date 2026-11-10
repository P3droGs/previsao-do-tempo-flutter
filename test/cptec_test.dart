import 'package:flutter_test/flutter_test.dart';
import 'package:previsao_tempo/cptec_service.dart';

void main() {
  test('lê a previsão de 4 dias', () {
    const xml =
        "<?xml version='1.0' encoding='ISO-8859-1'?><cidade><nome>São Paulo</nome><uf>SP</uf><atualizacao>2026-11-10</atualizacao>"
        '<previsao><dia>2026-11-10</dia><tempo>pn</tempo><maxima>20</maxima><minima>14</minima><iuv>5.0</iuv></previsao>'
        '<previsao><dia>2026-11-11</dia><tempo>c</tempo><maxima>23</maxima><minima>15</minima><iuv>0.0</iuv></previsao>'
        '<previsao><dia>2026-11-12</dia><tempo>t</tempo><maxima>25</maxima><minima>17</minima><iuv>0.0</iuv></previsao>'
        '<previsao><dia>2026-11-13</dia><tempo>cl</tempo><maxima>27</maxima><minima>19</minima><iuv>0.0</iuv></previsao></cidade>';
    final p = CptecService.lerPrevisao(xml);
    expect(p.dias.length, 4);
    expect(formatarData(p.atualizacao), '10/11/2026');
    expect(p.dias.first.minima, 14);
    expect(p.dias.first.maxima, 20);
    expect(p.dias.first.iuv, 5.0);
    expect(descricaoTempo(p.dias.first.tempo), 'Parcialmente Nublado');
  });

  test('remove acentos do nome buscado', () {
    expect(removerAcentos('São Paulo'), 'Sao Paulo');
    expect(removerAcentos('Jacareí'), 'Jacarei');
    expect(removerAcentos('Conceição do Araguaia'), 'Conceicao do Araguaia');
  });

  test('campos ausentes não quebram', () {
    final p = CptecService.lerPrevisao(
      '<cidade><previsao><dia>2026-11-10</dia></previsao></cidade>',
    );
    expect(p.atualizacao, isNull);
    expect(p.dias.single.minima, isNull);
    expect(p.dias.single.iuv, isNull);
    expect(descricaoTempo(p.dias.single.tempo), 'Condição não informada');
    expect(formatarData(null), '--');
  });

  test('código inexistente (tudo "null") vira previsão vazia', () {
    final p = CptecService.lerPrevisao(
      '<cidade><nome>null</nome><atualizacao>null</atualizacao>'
      '<previsao><dia>null</dia><tempo>null</tempo><maxima>null</maxima><minima>null</minima><iuv>0.0</iuv></previsao></cidade>',
    );
    expect(p.dias, isEmpty);
  });

  test('XML quebrado ou com outro conteúdo é resposta inválida', () {
    expect(
      () => CptecService.lerPrevisao('<html><body>erro'),
      throwsA(isA<CptecException>()),
    );
    expect(
      () => CptecService.lerPrevisao('<html><body>erro</body></html>'),
      throwsA(isA<CptecException>()),
    );
  });
}
