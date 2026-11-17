import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/core/session/sessao_usuario.dart';
import 'package:front_delivery/core/theme/app_colors.dart';
import 'package:front_delivery/core/widgets/paginacao.dart';
import 'package:front_delivery/features/pedidos/screens/pedidos_screen.dart';

import '../../helpers/api_falsa.dart';

Map<String, Object?> _pedido(int id, String status) => {
      'id': id,
      'status': status,
      'dataPedido': '2026-11-${(id % 28 + 1).toString().padLeft(2, '0')}T10:00:00',
      'valorTotal': 0,
    };

/// 12 pedidos em aberto (ids 1..12) e 13 no histórico (ids 101..113).
final _api = ApiFalsa((r) {
  if (r.url.path == '/pedidos/usuario/9') {
    return respostaJson([
      for (var i = 1; i <= 12; i++) _pedido(i, 'PENDENTE'),
      for (var i = 101; i <= 113; i++) _pedido(i, 'ENTREGUE'),
    ]);
  }
  return respostaJson([]); // itens de cada pedido
});

int _paginaAtual(WidgetTester tester) {
  final m = tester
      .widgetList<Material>(find.descendant(of: find.byType(Paginacao), matching: find.byType(Material)))
      .singleWhere((m) => m.color == kPrimary);
  return int.parse(tester.widget<Text>(find.descendant(of: find.byWidget(m), matching: find.byType(Text))).data!);
}

Finder get _cards => find.textContaining('Pedido #');

void main() {
  setUp(() => SessaoUsuario.id = 9);
  tearDown(() => SessaoUsuario.id = null);

  testWidgets('cada aba tem sua paginação e trocar de aba volta para a página 1', (tester) async {
    usarTelaAlta(tester);
    await _api.executar(() async {
      await tester.pumpWidget(const MaterialApp(home: PedidosScreen()));
      await tester.pumpAndSettle();
    });

    // Em Aberto: 12 pedidos -> 10 + 2.
    expect(_cards, findsNWidgets(10));
    await tester.tap(find.byKey(const ValueKey('pagina-2')));
    await tester.pumpAndSettle();
    expect(_cards, findsNWidgets(2));
    expect(_paginaAtual(tester), 2);

    // Histórico começa na página 1, independente da outra aba.
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(_cards, findsNWidgets(10));
    expect(_paginaAtual(tester), 1);
    await tester.tap(find.byTooltip('Próxima página'));
    await tester.pumpAndSettle();
    expect(_cards, findsNWidgets(3));

    // Voltar para Em Aberto: página 1 de novo.
    await tester.tap(find.text('Em Aberto'));
    await tester.pumpAndSettle();
    expect(_cards, findsNWidgets(10));
    expect(_paginaAtual(tester), 1);
  });
}
