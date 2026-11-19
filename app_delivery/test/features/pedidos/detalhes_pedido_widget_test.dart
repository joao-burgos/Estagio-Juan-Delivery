import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/core/session/sessao_usuario.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:front_delivery/features/pedidos/screens/detalhes_pedido_screen.dart';
import 'package:front_delivery/features/pedidos/screens/pedidos_screen.dart';

import '../../helpers/api_falsa.dart';

const _cancelarPedido = 'CANCELAR PEDIDO';
const _confirmarEntrega = 'CONFIRMAR ENTREGA';

/// Backend falso com um único pedido (#7, do usuário 9). O PATCH de status
/// grava o novo status, que passa a ser devolvido pelo GET; se [erroPatch]
/// for informado, o PATCH responde 400 com essa mensagem.
class _Backend {
  _Backend(this.status, {this.erroPatch});

  String status;
  final String? erroPatch;

  late final api = ApiFalsa((r) {
    if (r.method == 'PATCH' && r.url.path == '/pedidos/7/status') {
      if (erroPatch != null) return respostaJson({'erro': erroPatch}, 400);
      status = r.url.queryParameters['status']!;
      return respostaJson(_pedido());
    }
    if (r.url.path == '/pedidos/7') return respostaJson(_pedido());
    if (r.url.path == '/pedidos/7/itens') return respostaJson([_item]);
    if (r.url.path == '/pedidos/usuario/9') return respostaJson([_pedido()]);
    return respostaJson(const []);
  });

  Map<String, Object?> _pedido() => {
        'id': 7,
        'status': status,
        'dataPedido': DateTime.now().toIso8601String(),
        'valorTotal': 0,
      };

  static const _item = {
    'id': 1,
    'quantidade': 2,
    'precoUnit': 50.0,
    'produto': {'id': 1, 'nome': 'Malbec', 'preco': 50.0, 'estoque': 10},
  };

  Iterable get patches => api.doMetodo('PATCH');
}

Future<void> _abrirDetalhes(WidgetTester tester, _Backend backend) async {
  usarTelaAlta(tester);
  await backend.api.executar(() async {
    await tester.pumpWidget(const MaterialApp(home: DetalhesPedidoScreen(pedidoId: 7)));
    await tester.pumpAndSettle();
  });
}

Future<void> _tocar(WidgetTester tester, _Backend backend, Finder alvo) => backend.api.executar(() async {
      await tester.tap(alvo);
      await tester.pumpAndSettle();
    });

Finder _noDialogo(String texto) => find.descendant(of: find.byType(AlertDialog), matching: find.text(texto));

void main() {
  group('botões do pedido', () {
    for (final status in ['PENDENTE', 'CONFIRMADO', 'EM_PREPARO', 'EM_ENTREGA']) {
      testWidgets('pedido $status mostra Confirmar Entrega e Cancelar, do mesmo tamanho', (tester) async {
        await _abrirDetalhes(tester, _Backend(status));
        expect(find.text(_confirmarEntrega), findsOneWidget);
        expect(find.text(_cancelarPedido), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, _cancelarPedido), findsOneWidget);

        final confirmar = tester.getRect(find.byKey(const Key('botao_confirmar_entrega')));
        final cancelar = tester.getRect(find.byKey(const Key('botao_cancelar_pedido')));
        expect(cancelar.size, confirmar.size);
        expect(cancelar.top, greaterThan(confirmar.bottom)); // um abaixo do outro
      });
    }

    for (final status in ['ENTREGUE', 'CANCELADO']) {
      testWidgets('pedido $status não mostra os botões', (tester) async {
        await _abrirDetalhes(tester, _Backend(status));
        expect(find.text(_confirmarEntrega), findsNothing);
        expect(find.text(_cancelarPedido), findsNothing);
      });
    }

    testWidgets('os botões ficam acima da barra do total (não escondidos)', (tester) async {
      await _abrirDetalhes(tester, _Backend('PENDENTE'));
      final cancelar = tester.getRect(find.byKey(const Key('botao_cancelar_pedido')));
      final total = tester.getRect(find.text('Total'));
      expect(cancelar.bottom, lessThan(total.top));
    });
  });

  group('cancelar pedido', () {
    testWidgets('tocar em Cancelar abre o diálogo com o texto do pedido', (tester) async {
      final backend = _Backend('PENDENTE');
      await _abrirDetalhes(tester, backend);
      await _tocar(tester, backend, find.text(_cancelarPedido));

      expect(find.text('Cancelar pedido?'), findsOneWidget);
      expect(
        find.text('O pedido #7 será cancelado e os itens voltarão ao estoque. Essa ação não pode ser desfeita.'),
        findsOneWidget,
      );
      expect(_noDialogo('Voltar'), findsOneWidget);
      expect(_noDialogo('Cancelar pedido'), findsOneWidget);
    });

    testWidgets('"Voltar" fecha o diálogo sem chamar a API', (tester) async {
      final backend = _Backend('PENDENTE');
      await _abrirDetalhes(tester, backend);
      await _tocar(tester, backend, find.text(_cancelarPedido));
      await _tocar(tester, backend, _noDialogo('Voltar'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.patches, isEmpty);
      expect(find.text('Pendente'), findsOneWidget);
      expect(find.text(_cancelarPedido), findsOneWidget);
    });

    testWidgets('confirmar chama PATCH status=CANCELADO, o status vira Cancelado e os botões somem', (tester) async {
      final backend = _Backend('PENDENTE');
      await _abrirDetalhes(tester, backend);
      await _tocar(tester, backend, find.text(_cancelarPedido));
      await _tocar(tester, backend, _noDialogo('Cancelar pedido'));

      expect(backend.patches, hasLength(1));
      expect(backend.patches.single.url.queryParameters, {'status': 'CANCELADO'});
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Pedido cancelado. Os itens voltaram ao estoque.'), findsOneWidget);
      expect(find.text(_cancelarPedido), findsNothing);
      expect(find.text(_confirmarEntrega), findsNothing);
      expect(find.byType(SnackBar), findsNothing); // nada tampando a tela
    });

    testWidgets('enquanto a requisição roda, os botões ficam desabilitados', (tester) async {
      final backend = _Backend('PENDENTE');
      await _abrirDetalhes(tester, backend);
      // O PATCH só responde quando [liberar] completar.
      final liberar = Completer<void>();
      final cliente = MockClient((req) async {
        backend.api.requisicoes.add(req);
        if (req.method == 'PATCH') await liberar.future;
        return backend.api.responder(req);
      });
      await http.runWithClient(() async {
        await tester.tap(find.text(_cancelarPedido));
        await tester.pumpAndSettle();
        await tester.tap(_noDialogo('Cancelar pedido'));
        await tester.pump(); // fecha o diálogo e dispara a requisição
        await tester.pump();

        expect(tester.widget<OutlinedButton>(find.byKey(const Key('botao_cancelar_pedido'))).onPressed, isNull);
        expect(tester.widget<ElevatedButton>(find.byKey(const Key('botao_confirmar_entrega'))).onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byKey(const Key('botao_cancelar_pedido')), warnIfMissed: false); // toque duplo
        await tester.pump();

        liberar.complete();
        await tester.pumpAndSettle();
      }, () => cliente);
      expect(backend.patches, hasLength(1));
    });

    testWidgets('erro da API aparece na tela sem tampar os botões', (tester) async {
      final backend = _Backend('PENDENTE', erroPatch: 'Pedido já entregue não pode ser cancelado');
      await _abrirDetalhes(tester, backend);
      await _tocar(tester, backend, find.text(_cancelarPedido));
      await _tocar(tester, backend, _noDialogo('Cancelar pedido'));

      final erro = find.text('Pedido já entregue não pode ser cancelado');
      expect(erro, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Pendente'), findsOneWidget);
      // Botões continuam visíveis, habilitados e abaixo da mensagem.
      final botao = find.byKey(const Key('botao_cancelar_pedido'));
      expect(tester.widget<OutlinedButton>(botao).onPressed, isNotNull);
      expect(
          tester.getRect(erro).bottom, lessThan(tester.getRect(find.byKey(const Key('botao_confirmar_entrega'))).top));
    });

    testWidgets('pedido cancelado vai para a aba Histórico de Meus Pedidos', (tester) async {
      SessaoUsuario.id = 9;
      addTearDown(() => SessaoUsuario.id = null);
      usarTelaAlta(tester);
      final backend = _Backend('PENDENTE');
      await backend.api.executar(() async {
        await tester.pumpWidget(const MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: [Locale('pt', 'BR')],
          home: PedidosScreen(),
        ));
        await tester.pumpAndSettle();
      });
      expect(find.text('Pedido #7'), findsOneWidget); // em aberto

      await _tocar(tester, backend, find.text('Pedido #7'));
      await _tocar(tester, backend, find.text(_cancelarPedido));
      await _tocar(tester, backend, _noDialogo('Cancelar pedido'));
      await backend.api.executar(() async {
        Navigator.of(tester.element(find.byType(DetalhesPedidoScreen))).pop();
        await tester.pumpAndSettle();
      });

      expect(find.text('Pedido #7'), findsNothing); // saiu de Em Aberto
      await _tocar(tester, backend, find.text('Histórico'));
      expect(find.text('Pedido #7'), findsOneWidget);
    });
  });

  group('confirmar entrega', () {
    testWidgets('abre o diálogo antes de chamar a API; "Voltar" não chama', (tester) async {
      final backend = _Backend('EM_ENTREGA');
      await _abrirDetalhes(tester, backend);
      await _tocar(tester, backend, find.text(_confirmarEntrega));

      expect(find.text('Confirmar entrega?'), findsOneWidget);
      expect(find.text('Confirme apenas se você já recebeu o pedido #7.'), findsOneWidget);
      expect(_noDialogo('Voltar'), findsOneWidget);
      expect(_noDialogo('Confirmar'), findsOneWidget);
      expect(backend.patches, isEmpty);

      await _tocar(tester, backend, _noDialogo('Voltar'));
      expect(backend.patches, isEmpty);
      expect(find.text(_confirmarEntrega), findsOneWidget);
    });

    testWidgets('"Confirmar" chama PATCH status=ENTREGUE', (tester) async {
      final backend = _Backend('EM_ENTREGA');
      await _abrirDetalhes(tester, backend);
      await _tocar(tester, backend, find.text(_confirmarEntrega));
      await _tocar(tester, backend, _noDialogo('Confirmar'));

      expect(backend.patches, hasLength(1));
      expect(backend.patches.single.url.queryParameters, {'status': 'ENTREGUE'});
    });
  });
}
