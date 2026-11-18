import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/core/theme/app_colors.dart';
import 'package:front_delivery/core/widgets/paginacao.dart';

/// Monta a paginação com estado próprio e devolve as páginas escolhidas.
Future<List<int>> _montar(WidgetTester tester, {required int total, int inicial = 1}) async {
  final escolhidas = <int>[];
  var pagina = inicial;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => Paginacao(
          totalItens: total,
          paginaAtual: pagina,
          onPaginaChanged: (p) => setState(() {
            escolhidas.add(p);
            pagina = p;
          }),
        ),
      ),
    ),
  ));
  return escolhidas;
}

IconButton _seta(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)));

/// Número da página destacada (fundo kPrimary).
int _paginaDestacada(WidgetTester tester) {
  final destacadas = tester
      .widgetList<Material>(find.descendant(of: find.byType(Paginacao), matching: find.byType(Material)))
      .where((m) => m.color == kPrimary)
      .toList();
  expect(destacadas, hasLength(1));
  final texto = find.descendant(of: find.byWidget(destacadas.single), matching: find.byType(Text));
  return int.parse(tester.widget<Text>(texto).data!);
}

void main() {
  group('funções de paginação', () {
    test('totalPaginas', () {
      expect(totalPaginas(0), 1);
      expect(totalPaginas(10), 1);
      expect(totalPaginas(11), 2);
      expect(totalPaginas(25), 3);
    });

    test('fatiarPagina devolve 10, 10 e 5 itens para 25', () {
      final lista = List.generate(25, (i) => i + 1);
      expect(fatiarPagina(lista, 1), List.generate(10, (i) => i + 1));
      expect(fatiarPagina(lista, 2), List.generate(10, (i) => i + 11));
      expect(fatiarPagina(lista, 3), [21, 22, 23, 24, 25]);
    });

    test('página que ficou vazia volta para a anterior', () {
      expect(paginaValida(3, 20), 2);
      expect(paginaValida(3, 21), 3);
      expect(paginaValida(2, 0), 1);
      expect(fatiarPagina(List.generate(20, (i) => i), 3), hasLength(10));
    });

    test('reticências com muitas páginas', () {
      expect(paginasVisiveis(1, 3), [1, 2, 3]);
      expect(paginasVisiveis(1, 7), [1, 2, 3, 4, 5, 6, 7]);
      expect(paginasVisiveis(1, 12), [1, 2, 3, 4, 5, null, 12]);
      expect(paginasVisiveis(5, 12), [1, null, 4, 5, 6, null, 12]);
      expect(paginasVisiveis(12, 12), [1, null, 8, 9, 10, 11, 12]);
    });
  });

  group('widget Paginacao', () {
    testWidgets('não aparece com 10 itens ou menos', (tester) async {
      for (final total in [0, 1, 10]) {
        await _montar(tester, total: total);
        expect(find.byTooltip('Próxima página'), findsNothing, reason: '$total itens');
        expect(find.text('1'), findsNothing, reason: '$total itens');
      }
    });

    testWidgets('aparece com 11 itens: duas páginas', (tester) async {
      await _montar(tester, total: 11);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
      expect(_paginaDestacada(tester), 1);
    });

    testWidgets('avança e volta pelas setas e pelos números', (tester) async {
      final escolhidas = await _montar(tester, total: 25);
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pump();
      expect(_paginaDestacada(tester), 2);

      await tester.tap(find.byKey(const ValueKey('pagina-3')));
      await tester.pump();
      expect(_paginaDestacada(tester), 3);

      await tester.tap(find.byTooltip('Página anterior'));
      await tester.pump();
      expect(_paginaDestacada(tester), 2);
      expect(escolhidas, [2, 3, 2]);
    });

    testWidgets('"anterior" desabilitado na primeira e "próxima" na última', (tester) async {
      await _montar(tester, total: 25);
      expect(_seta(tester, 'Página anterior').onPressed, isNull);
      expect(_seta(tester, 'Próxima página').onPressed, isNotNull);

      await _montar(tester, total: 25, inicial: 3);
      expect(_seta(tester, 'Página anterior').onPressed, isNotNull);
      expect(_seta(tester, 'Próxima página').onPressed, isNull);
    });

    testWidgets('com muitas páginas mostra reticências', (tester) async {
      await _montar(tester, total: 120, inicial: 5); // 12 páginas
      expect(find.text('…'), findsNWidgets(2));
      for (final p in ['1', '4', '5', '6', '12']) {
        expect(find.text(p), findsOneWidget, reason: p);
      }
      expect(find.text('2'), findsNothing);
      expect(find.text('11'), findsNothing);
    });

    testWidgets('cabe em tela de celular estreita sem overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _montar(tester, total: 120, inicial: 5);
      expect(tester.takeException(), isNull);
    });
  });
}
