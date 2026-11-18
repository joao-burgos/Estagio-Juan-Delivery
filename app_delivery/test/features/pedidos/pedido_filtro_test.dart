import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/features/pedidos/filters/pedido_filtro.dart';
import 'package:front_delivery/features/pedidos/models/pedido.dart';

Pedido _pedido(int id, DateTime? data, {double valor = 0}) =>
    Pedido(id: id, usuarioId: 1, status: 'PENDENTE', dataPedido: data, valorTotal: valor);

List<int> _ids(List<Pedido> lista) => [for (final p in lista) p.id];

void main() {
  // "Agora" fixo: 17/11/2026 às 15:00.
  final agora = DateTime(2026, 11, 17, 15);

  group('IntervaloDatas', () {
    final periodo = IntervaloDatas(DateTime(2026, 11, 1), DateTime(2026, 11, 17));

    test('é inclusivo: o primeiro dia desde 00:00 e o último até 23:59:59', () {
      expect(periodo.contem(DateTime(2026, 11, 1)), isTrue);
      expect(periodo.contem(DateTime(2026, 11, 17, 23, 59, 59)), isTrue);
      expect(periodo.contem(DateTime(2026, 10, 31, 23, 59, 59)), isFalse);
      expect(periodo.contem(DateTime(2026, 11, 18)), isFalse);
    });

    test('rótulo legível', () {
      expect(periodo.rotulo, '01/11/2026 – 17/11/2026');
      expect(IntervaloDatas(DateTime(2026, 11, 17), DateTime(2026, 11, 17)).rotulo, '17/11/2026');
    });

    test('ignora a hora das pontas', () {
      final p = IntervaloDatas(DateTime(2026, 11, 1, 18), DateTime(2026, 11, 17, 8));
      expect(p.contem(DateTime(2026, 11, 1, 0, 0)), isTrue);
      expect(p.contem(DateTime(2026, 11, 17, 22)), isTrue);
    });
  });

  group('PedidoFiltro por data', () {
    final pedidos = [
      _pedido(1, DateTime(2026, 11, 17, 9)), // hoje
      _pedido(2, DateTime(2026, 11, 11, 0, 0)), // 6 dias atrás (entra em 7 dias)
      _pedido(3, DateTime(2026, 11, 10, 23, 59)), // 7 dias atrás (fica fora de 7 dias)
      _pedido(4, DateTime(2026, 10, 19)), // 29 dias atrás (entra em 30 dias)
      _pedido(5, DateTime(2026, 10, 18)), // 30 dias atrás (fica fora)
      _pedido(6, null), // sem data
    ];

    List<int> aplicar(PedidoFiltro f) =>
        _ids(f.aplicar(pedidos, totais: const {}, quantidades: const {}, agora: agora));

    test('sem filtro mostra todos, inclusive sem data', () {
      expect(aplicar(const PedidoFiltro()), [1, 2, 3, 4, 5, 6]);
    });

    test('atalhos Hoje, Últimos 7 dias e Últimos 30 dias', () {
      expect(aplicar(const PedidoFiltro(periodo: PeriodoPedido.hoje)), [1]);
      expect(aplicar(const PedidoFiltro(periodo: PeriodoPedido.ultimos7Dias)), [1, 2]);
      expect(aplicar(const PedidoFiltro(periodo: PeriodoPedido.ultimos30Dias)), [1, 2, 3, 4]);
    });

    test('personalizado: pedidos fora somem e o último dia do período entra', () {
      final f = const PedidoFiltro()
          .comPeriodo(PeriodoPedido.personalizado, IntervaloDatas(DateTime(2026, 10, 19), DateTime(2026, 11, 10)));
      expect(aplicar(f), [3, 4]);
    });

    test('intervalo dos atalhos mostrado no painel', () {
      expect(
          const PedidoFiltro(periodo: PeriodoPedido.ultimos7Dias).intervalo(agora)!.rotulo, '11/11/2026 – 17/11/2026');
    });
  });

  group('PedidoFiltro por valor e quantidade', () {
    final pedidos = [_pedido(1, agora, valor: 49.9), _pedido(2, agora), _pedido(3, agora), _pedido(4, agora)];
    // Totais somados dos itens (o pedido 1 não tem itens carregados e usa valorTotal).
    const totais = {2: 100.0, 3: 250.5, 4: 10.0};
    const quantidades = {2: 2, 3: 5, 4: 1};

    List<int> aplicar(PedidoFiltro f) => _ids(f.aplicar(pedidos, totais: totais, quantidades: quantidades));

    test('valor mínimo e máximo inclusivos', () {
      expect(aplicar(const PedidoFiltro(valorMin: 49.9)), [1, 2, 3]);
      expect(aplicar(const PedidoFiltro(valorMax: 100)), [1, 2, 4]);
      expect(aplicar(const PedidoFiltro(valorMin: 49.9, valorMax: 100)), [1, 2]);
    });

    test('quantidade mínima e máxima; pedido sem itens carregados não passa', () {
      expect(aplicar(const PedidoFiltro(quantidadeMin: 2)), [2, 3]);
      expect(aplicar(const PedidoFiltro(quantidadeMax: 2)), [2, 4]);
      expect(aplicar(const PedidoFiltro(quantidadeMin: 2, quantidadeMax: 2)), [2]);
    });

    test('lerValor aceita vírgula ou ponto', () {
      expect(lerValor('49,90'), 49.9);
      expect(lerValor('49.9'), 49.9);
      expect(lerValor('1.234,50'), 1234.5);
      expect(lerValor(''), isNull);
      expect(lerValor(','), isNull);
    });
  });

  group('PedidoFiltro validação e contagem', () {
    test('mínimo maior que o máximo gera erro', () {
      expect(const PedidoFiltro(valorMin: 300, valorMax: 100).erro, contains('valor mínimo'));
      expect(const PedidoFiltro(quantidadeMin: 5, quantidadeMax: 2).erro, contains('quantidade mínima'));
      expect(const PedidoFiltro(valorMin: 100, valorMax: 100).erro, isNull);
    });

    test('data inicial depois da final gera erro', () {
      final f = PedidoFiltro(
        periodo: PeriodoPedido.personalizado,
        personalizado: IntervaloDatas(DateTime(2026, 11, 17), DateTime(2026, 11, 1)),
      );
      expect(f.erro, contains('data inicial'));
    });

    test('conta os grupos de filtro ativos', () {
      expect(const PedidoFiltro().ativos, 0);
      expect(const PedidoFiltro(periodo: PeriodoPedido.hoje, valorMin: 1, quantidadeMax: 3).ativos, 3);
      expect(const PedidoFiltro(valorMin: 1, valorMax: 2).ativos, 1);
    });
  });
}
