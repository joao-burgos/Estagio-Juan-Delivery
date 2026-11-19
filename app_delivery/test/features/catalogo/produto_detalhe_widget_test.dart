import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:front_delivery/features/carrinho/controllers/carrinho_controller.dart';
import 'package:front_delivery/features/carrinho/widgets/carrinho_appbar_action.dart';
import 'package:front_delivery/features/catalogo/screens/produto_detalhe_screen.dart';

import '../../helpers/api_falsa.dart';

Map<String, dynamic> _vinho({String? harmonizacao}) => {
      'id': 7,
      'nome': 'Malbec Reserva',
      'preco': 89.9,
      'tipo': 'VINHO',
      'estoque': 10,
      'ativo': true,
      'categoria': 'VINHO_TINTO',
      'paisOrigem': 'Argentina',
      'safra': 2020,
      'teorAlcool': 13.5,
      'harmonizacao': harmonizacao,
    };

Future<void> _abrirDetalhe(WidgetTester tester, Map<String, dynamic> produto) async {
  usarTelaAlta(tester);
  final api = ApiFalsa((_) => respostaJson(produto));
  await api.executar(() async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: CarrinhoController.instance,
        child: const MaterialApp(home: ProdutoDetalheScreen(id: 7)),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  setUp(CarrinhoController.instance.limpar);

  testWidgets('adicionar ao carrinho para no estoque disponível', (tester) async {
    await _abrirDetalhe(tester, {..._vinho(harmonizacao: 'Carnes vermelhas'), 'estoque': 2});
    final adicionar = find.widgetWithText(ElevatedButton, 'ADICIONAR AO CARRINHO');
    await tester.tap(adicionar);
    await tester.pump();
    await tester.tap(adicionar);
    await tester.pump();
    expect(CarrinhoController.instance.itens.single.quantidade, 2);
    expect(find.text('No carrinho: 2 de 2 disponível(is)'), findsOneWidget);

    final botao = find.widgetWithText(ElevatedButton, 'ESTOQUE MÁXIMO NO CARRINHO');
    expect(tester.widget<ElevatedButton>(botao).onPressed, isNull);
    await tester.tap(botao);
    await tester.pump();
    expect(CarrinhoController.instance.itens.single.quantidade, 2);
    await tester.pump(const Duration(seconds: 3)); // deixa a confirmação e o aviso de limite expirarem
  });

  group('feedback ao adicionar ao carrinho', () {
    testWidgets('adicionar não mostra SnackBar e o badge mostra a nova quantidade', (tester) async {
      await _abrirDetalhe(tester, _vinho());
      expect(find.byKey(const ValueKey('badge-carrinho')), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ADICIONAR AO CARRINHO'));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Produto adicionado ao carrinho!'), findsNothing);
      final badge = find.byKey(const ValueKey('badge-carrinho'));
      expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);

      await tester.pump(const Duration(seconds: 2)); // confirmação expira
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'ADICIONAR AO CARRINHO'));
      await tester.pump();
      expect(find.descendant(of: badge, matching: find.text('2')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('o ícone do carrinho dá um pulo e volta ao tamanho normal', (tester) async {
      await _abrirDetalhe(tester, _vinho());
      ScaleTransition escala() => tester.widget<ScaleTransition>(
          find.descendant(of: find.byType(CarrinhoAppBarAction), matching: find.byType(ScaleTransition)));
      expect(escala().scale.value, 1.0);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ADICIONAR AO CARRINHO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150)); // metade do pulo
      expect(escala().scale.value, closeTo(1.25, 0.01));
      await tester.pump(const Duration(milliseconds: 200));
      expect(escala().scale.value, 1.0);
      await tester.pumpAndSettle();
    });

    testWidgets('o botão mostra "ADICIONADO" e volta ao texto original depois de ~2 s', (tester) async {
      await _abrirDetalhe(tester, _vinho());
      await tester.tap(find.widgetWithText(ElevatedButton, 'ADICIONAR AO CARRINHO'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 1)); // termina a transição, sem chegar aos 2 s
      expect(find.text('ADICIONADO'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('ADICIONAR AO CARRINHO'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('ADICIONADO'), findsNothing);
      expect(find.text('ADICIONAR AO CARRINHO'), findsOneWidget);
    });

    testWidgets('tocar de novo durante a confirmação adiciona e reinicia o tempo', (tester) async {
      await _abrirDetalhe(tester, _vinho());
      final botao = find.byType(ElevatedButton);
      await tester.tap(botao);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('ADICIONADO'), findsOneWidget);

      await tester.tap(botao);
      await tester.pump();
      expect(CarrinhoController.instance.itens.single.quantidade, 2);
      await tester.pump(const Duration(milliseconds: 1500)); // 3 s desde o 1º toque, 1,5 s desde o 2º
      expect(find.text('ADICIONADO'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('ADICIONAR AO CARRINHO'), findsOneWidget);
    });

    testWidgets('passar do estoque mostra a mensagem de limite abaixo do botão, sem SnackBar', (tester) async {
      await _abrirDetalhe(tester, {..._vinho(), 'estoque': 1});
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Limite de estoque atingido'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ESTOQUE MÁXIMO NO CARRINHO'));
      await tester.pumpAndSettle(); // termina de abrir o espaço da mensagem (o timer de 3 s segue correndo)
      expect(find.text('Limite de estoque atingido'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(CarrinhoController.instance.itens.single.quantidade, 1);
      // a mensagem fica abaixo do botão, sem tampá-lo
      expect(tester.getTopLeft(find.text('Limite de estoque atingido')).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.byType(ElevatedButton)).dy));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Limite de estoque atingido'), findsNothing);
    });

    testWidgets('sair da tela durante a confirmação não dá erro', (tester) async {
      await _abrirDetalhe(tester, _vinho());
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 100)); // pulo e confirmação em andamento
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('vinho com harmonização mostra a seção', (tester) async {
    await _abrirDetalhe(tester, _vinho(harmonizacao: 'Carnes vermelhas'));
    expect(find.text('Harmonização: '), findsOneWidget);
    expect(find.text('Carnes vermelhas'), findsOneWidget);
  });

  for (final semHarmonizacao in [null, '', '   ']) {
    testWidgets('vinho com harmonização ${semHarmonizacao == null ? 'null' : '"$semHarmonizacao"'} esconde a seção',
        (tester) async {
      await _abrirDetalhe(tester, _vinho(harmonizacao: semHarmonizacao));
      expect(find.text('Teor alcoólico: '), findsOneWidget); // a tela carregou
      expect(find.text('Harmonização: '), findsNothing);
    });
  }
}
