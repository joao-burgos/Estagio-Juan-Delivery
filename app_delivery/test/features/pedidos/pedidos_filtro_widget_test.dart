import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/core/session/sessao_usuario.dart';
import 'package:front_delivery/core/theme/app_colors.dart';
import 'package:front_delivery/core/widgets/paginacao.dart';
import 'package:front_delivery/features/pedidos/screens/pedidos_screen.dart';

import '../../helpers/api_falsa.dart';

final _hoje = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}();

/// Data [dias] dias atrás, na hora indicada.
DateTime _diasAtras(int dias, [int hora = 10, int minuto = 0, int segundo = 0]) =>
    DateTime(_hoje.year, _hoje.month, _hoje.day - dias, hora, minuto, segundo);

Map<String, Object?> _pedido(int id, String status, DateTime data) => {
      'id': id,
      'status': status,
      'dataPedido': data.toIso8601String(),
      'valorTotal': 0,
    };

Map<String, Object?> _item(int quantidade, double preco) => {
      'id': 1,
      'quantidade': quantidade,
      'precoUnit': preco,
      'produto': {'id': 1, 'nome': 'Malbec', 'preco': preco, 'estoque': 10},
    };

/// Monta o backend falso: [pedidos] da lista e os [itens] de cada pedido.
ApiFalsa _api(List<Map<String, Object?>> pedidos, [Map<int, List<Map<String, Object?>>> itens = const {}]) =>
    ApiFalsa((r) {
      if (r.url.path == '/pedidos/usuario/9') return respostaJson(pedidos);
      final m = RegExp(r'^/pedidos/(\d+)/itens$').firstMatch(r.url.path);
      if (m != null) return respostaJson(itens[int.parse(m[1]!)] ?? const []);
      return respostaJson(const []);
    });

Future<void> _abrirTela(WidgetTester tester, ApiFalsa api) async {
  usarTelaAlta(tester);
  await api.executar(() async {
    await tester.pumpWidget(const MaterialApp(home: PedidosScreen()));
    await tester.pumpAndSettle();
  });
}

Future<void> _abrirFiltros(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtros'));
  await tester.pumpAndSettle();
}

Future<void> _aplicar(WidgetTester tester) async {
  await tester.tap(find.text('Aplicar'));
  await tester.pumpAndSettle();
}

Future<void> _irPara(WidgetTester tester, String aba) async {
  await tester.tap(find.text(aba));
  await tester.pumpAndSettle();
}

/// Ids dos cards visíveis, na ordem.
List<int> _idsVisiveis(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.textContaining('Pedido #')))
        int.parse(t.data!.replaceFirst('Pedido #', '')),
    ];

int _paginaAtual(WidgetTester tester) {
  final m = tester
      .widgetList<Material>(find.descendant(of: find.byType(Paginacao), matching: find.byType(Material)))
      .singleWhere((m) => m.color == kPrimary);
  return int.parse(tester.widget<Text>(find.descendant(of: find.byWidget(m), matching: find.byType(Text))).data!);
}

/// Texto do badge do botão de filtros, ou `null` se escondido.
String? _badge(WidgetTester tester) {
  final badge = tester.widget<Badge>(find.descendant(of: find.byTooltip('Filtros'), matching: find.byType(Badge)));
  return badge.isLabelVisible ? (badge.label as Text).data : null;
}

const _semResultados = 'Nenhum pedido encontrado com esses filtros';

void main() {
  setUp(() => SessaoUsuario.id = 9);
  tearDown(() => SessaoUsuario.id = null);

  group('filtros de Meus Pedidos', () {
    // Em Aberto: 1 (hoje 10h, R$ 50, 1 item), 6 (hoje 23:59:59, R$ 20, 1 item),
    //            2 (3 dias, R$ 120, 2 itens), 3 (10 dias, R$ 300, 3 itens)
    // Histórico: 5 (2 dias, R$ 80, 4 itens), 4 (40 dias, R$ 30, 1 item)
    ApiFalsa api() => _api([
          _pedido(1, 'PENDENTE', _diasAtras(0)),
          _pedido(6, 'PENDENTE', _diasAtras(0, 23, 59, 59)),
          _pedido(2, 'CONFIRMADO', _diasAtras(3)),
          _pedido(3, 'EM_PREPARO', _diasAtras(10)),
          _pedido(4, 'ENTREGUE', _diasAtras(40)),
          _pedido(5, 'CANCELADO', _diasAtras(2)),
        ], {
          1: [_item(1, 50)],
          6: [_item(1, 20)],
          2: [_item(2, 60)],
          3: [_item(3, 100)],
          4: [_item(1, 30)],
          5: [_item(4, 20)],
        });

    testWidgets('sem filtro mostra todos e não há badge', (tester) async {
      await _abrirTela(tester, api());
      expect(_idsVisiveis(tester), [1, 6, 2, 3]);
      expect(_badge(tester), isNull);
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('"Hoje" mostra só os pedidos de hoje, inclusive às 23:59:59, nas duas abas', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.tap(find.text('Hoje'));
      await tester.pumpAndSettle();
      // O período escolhido aparece de forma legível no painel.
      final hoje = _diasAtras(0);
      final rotulo = '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
      expect(find.byKey(const ValueKey('rotulo-periodo')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('rotulo-periodo'))).data, rotulo);
      await _aplicar(tester);

      expect(_idsVisiveis(tester), [1, 6]);
      expect(_badge(tester), '1');
      expect(tester.widget<Text>(find.byKey(const ValueKey('resumo-filtros'))).data, rotulo);

      await _irPara(tester, 'Histórico');
      expect(_idsVisiveis(tester), isEmpty);
      expect(find.text(_semResultados), findsOneWidget);
    });

    testWidgets('"Últimos 7 dias" esconde os pedidos mais antigos', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.tap(find.text('Últimos 7 dias'));
      await _aplicar(tester);

      expect(_idsVisiveis(tester), [1, 6, 2]);
      await _irPara(tester, 'Histórico');
      expect(_idsVisiveis(tester), [5]);
    });

    testWidgets('filtro por valor mínimo e máximo (com vírgula) usa o total dos itens', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.enterText(find.byKey(const ValueKey('Valor mínimo')), '50');
      await tester.enterText(find.byKey(const ValueKey('Valor máximo')), '120,00');
      await tester.pumpAndSettle();
      await _aplicar(tester);

      expect(_idsVisiveis(tester), [1, 2]);
      expect(tester.widget<Text>(find.byKey(const ValueKey('resumo-filtros'))).data, 'R\$ 50,00 a R\$ 120,00');
      await _irPara(tester, 'Histórico');
      expect(_idsVisiveis(tester), [5]);
    });

    testWidgets('filtro por quantidade de itens', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.enterText(find.byKey(const ValueKey('Mínimo de itens')), '2');
      await tester.enterText(find.byKey(const ValueKey('Máximo de itens')), '3');
      await tester.pumpAndSettle();
      await _aplicar(tester);

      expect(_idsVisiveis(tester), [2, 3]);
      await _irPara(tester, 'Histórico');
      expect(find.text(_semResultados), findsOneWidget);
    });

    testWidgets('mínimo maior que o máximo mostra aviso e desativa Aplicar', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.enterText(find.byKey(const ValueKey('Valor mínimo')), '300');
      await tester.enterText(find.byKey(const ValueKey('Valor máximo')), '100');
      await tester.pumpAndSettle();

      expect(find.text('O valor mínimo não pode ser maior que o máximo'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Aplicar')).onPressed, isNull);

      // Corrigindo, o aviso some e dá para aplicar.
      await tester.enterText(find.byKey(const ValueKey('Valor máximo')), '400');
      await tester.pumpAndSettle();
      expect(find.text('O valor mínimo não pode ser maior que o máximo'), findsNothing);
      await _aplicar(tester);
      expect(_idsVisiveis(tester), [3]);
    });

    testWidgets('campo de valor ignora letras e mais de 2 casas decimais', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      final campo = find.byKey(const ValueKey('Valor mínimo'));
      await tester.enterText(campo, '12,5');
      await tester.enterText(campo, '12,5x');
      await tester.enterText(campo, '12,555');
      expect(tester.widget<TextField>(campo).controller!.text, '12,5');
    });

    testWidgets('"Limpar filtros" mostra tudo de novo (faixa de cima e estado vazio)', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.tap(find.text('Hoje'));
      await tester.enterText(find.byKey(const ValueKey('Mínimo de itens')), '5');
      await tester.pumpAndSettle();
      await _aplicar(tester);
      expect(_badge(tester), '2');
      expect(find.text(_semResultados), findsOneWidget);

      // Botão do estado vazio.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpar filtros'));
      await tester.pumpAndSettle();
      expect(_idsVisiveis(tester), [1, 6, 2, 3]);
      expect(_badge(tester), isNull);

      // Link da faixa de filtros ativos.
      await _abrirFiltros(tester);
      await tester.tap(find.text('Últimos 7 dias'));
      await _aplicar(tester);
      expect(_idsVisiveis(tester), [1, 6, 2]);
      await tester.tap(find.widgetWithText(TextButton, 'Limpar filtros'));
      await tester.pumpAndSettle();
      expect(_idsVisiveis(tester), [1, 6, 2, 3]);

      // "Limpar" dentro do painel também zera.
      await _abrirFiltros(tester);
      await tester.tap(find.text('Hoje'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpar'));
      await tester.pumpAndSettle();
      expect(_idsVisiveis(tester), [1, 6, 2, 3]);
      expect(_badge(tester), isNull);
    });

    testWidgets('"Personalizado" abre o seletor em português e o último dia do período entra', (tester) async {
      usarTelaAlta(tester);
      await api().executar(() async {
        await tester.pumpWidget(const MaterialApp(
          locale: Locale('pt', 'BR'),
          supportedLocales: [Locale('pt', 'BR')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PedidosScreen(),
        ));
        await tester.pumpAndSettle();
      });
      await _abrirFiltros(tester);
      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();
      expect(find.text('Selecione o período'), findsOneWidget);

      // Troca para digitação e informa de 10 dias atrás até 3 dias atrás.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      String dia(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      final dialogo = find.byType(DateRangePickerDialog);
      final campos = find.descendant(of: dialogo, matching: find.byType(TextField));
      await tester.enterText(campos.at(0), dia(_diasAtras(10)));
      await tester.enterText(campos.at(1), dia(_diasAtras(3)));
      await tester.tap(find.descendant(of: dialogo, matching: find.text('Aplicar')));
      await tester.pumpAndSettle();

      final rotulo = '${dia(_diasAtras(10))} – ${dia(_diasAtras(3))}';
      expect(tester.widget<Text>(find.byKey(const ValueKey('rotulo-periodo'))).data, rotulo);
      await _aplicar(tester);

      // 2 é do último dia do período (3 dias atrás); 3 é do primeiro; 1 e 6 (hoje) ficam fora.
      expect(_idsVisiveis(tester), [2, 3]);
      expect(tester.widget<Text>(find.byKey(const ValueKey('resumo-filtros'))).data, rotulo);
    });

    testWidgets('reabrir o painel mantém os valores aplicados', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.enterText(find.byKey(const ValueKey('Valor mínimo')), '49,9');
      await tester.pumpAndSettle();
      await _aplicar(tester);

      await _abrirFiltros(tester);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('Valor mínimo'))).controller!.text, '49,90');
    });
  });

  group('filtro + paginação', () {
    // Em Aberto: 25 pedidos de ontem (1..25) + 5 de 20 dias atrás (26..30).
    // Histórico: 12 pedidos de ontem (101..112).
    ApiFalsa api() => _api([
          for (var i = 1; i <= 25; i++) _pedido(i, 'PENDENTE', _diasAtras(1)),
          for (var i = 26; i <= 30; i++) _pedido(i, 'PENDENTE', _diasAtras(20)),
          for (var i = 101; i <= 112; i++) _pedido(i, 'ENTREGUE', _diasAtras(1)),
        ]);

    testWidgets('paginação usa a lista filtrada e aplicar filtro volta para a página 1', (tester) async {
      await _abrirTela(tester, api());
      expect(find.byKey(const ValueKey('pagina-3')), findsOneWidget); // 30 pedidos

      await _abrirFiltros(tester);
      await tester.tap(find.text('Últimos 7 dias'));
      await _aplicar(tester);

      // 25 no período: 10 + 10 + 5.
      expect(_idsVisiveis(tester).length, 10);
      expect(find.byKey(const ValueKey('pagina-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('pagina-4')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pagina-3')));
      await tester.pumpAndSettle();
      expect(_idsVisiveis(tester), [21, 22, 23, 24, 25]);
      expect(_paginaAtual(tester), 3);

      // Aplicar outro filtro (30 dias: os 30 pedidos) volta para a página 1.
      await _abrirFiltros(tester);
      await tester.tap(find.text('Últimos 30 dias'));
      await _aplicar(tester);
      expect(_paginaAtual(tester), 1);
      expect(_idsVisiveis(tester), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      // Limpar também volta para a página 1.
      await tester.tap(find.byKey(const ValueKey('pagina-2')));
      await tester.pumpAndSettle();
      expect(_paginaAtual(tester), 2);
      await tester.tap(find.widgetWithText(TextButton, 'Limpar filtros'));
      await tester.pumpAndSettle();
      expect(_paginaAtual(tester), 1);

      // Histórico: 12 pedidos de ontem -> 2 páginas, começando na 1.
      await _irPara(tester, 'Histórico');
      expect(_paginaAtual(tester), 1);
      expect(_idsVisiveis(tester).length, 10);
    });

    testWidgets('filtro que deixa uma página só esconde a paginação', (tester) async {
      await _abrirTela(tester, api());
      await _abrirFiltros(tester);
      await tester.tap(find.text('Últimos 30 dias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoje'));
      await _aplicar(tester);
      expect(find.text(_semResultados), findsOneWidget);
      expect(find.byKey(const ValueKey('pagina-1')), findsNothing);
    });
  });
}
