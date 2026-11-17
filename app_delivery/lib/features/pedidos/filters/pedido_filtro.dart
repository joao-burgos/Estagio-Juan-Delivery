import '../../../core/utils/formatadores.dart';
import '../models/pedido.dart';

/// Atalhos de período do filtro de pedidos.
enum PeriodoPedido {
  todos('Todos'),
  hoje('Hoje'),
  ultimos7Dias('Últimos 7 dias'),
  ultimos30Dias('Últimos 30 dias'),
  personalizado('Personalizado');

  final String label;
  const PeriodoPedido(this.label);
}

/// Período de datas fechado nas duas pontas: [inicio] desde 00:00 e [fim]
/// até 23:59:59. Só o dia importa; a hora de [inicio] e [fim] é ignorada.
class IntervaloDatas {
  final DateTime inicio;
  final DateTime fim;

  IntervaloDatas(DateTime inicio, DateTime fim)
      : inicio = DateTime(inicio.year, inicio.month, inicio.day),
        fim = DateTime(fim.year, fim.month, fim.day);

  bool get valido => !inicio.isAfter(fim);

  /// Inclusivo: o último dia vale até 23:59:59 (comparado com o início do dia seguinte).
  bool contem(DateTime data) {
    final limite = DateTime(fim.year, fim.month, fim.day + 1);
    return !data.isBefore(inicio) && data.isBefore(limite);
  }

  /// Ex.: "01/11/2026 – 17/11/2026" (ou só uma data quando início e fim são o mesmo dia).
  String get rotulo {
    final a = formatarDia(inicio), b = formatarDia(fim);
    return a == b ? a : '$a – $b';
  }

  @override
  bool operator ==(Object other) => other is IntervaloDatas && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(inicio, fim);
}

/// Lê um valor digitado com vírgula ou ponto decimal ("49,90", "49.9", "50").
/// Vazio ou inválido devolve `null` (sem limite).
double? lerValor(String texto) {
  var t = texto.trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Estado imutável dos filtros de Meus Pedidos. A filtragem é local, sobre os
/// pedidos já carregados; vale para as abas Em Aberto e Histórico.
class PedidoFiltro {
  final PeriodoPedido periodo;

  /// Usado só quando [periodo] é [PeriodoPedido.personalizado].
  final IntervaloDatas? personalizado;

  /// Limites de valor total e de quantidade de itens; `null` = sem limite.
  final double? valorMin;
  final double? valorMax;
  final int? quantidadeMin;
  final int? quantidadeMax;

  const PedidoFiltro({
    this.periodo = PeriodoPedido.todos,
    this.personalizado,
    this.valorMin,
    this.valorMax,
    this.quantidadeMin,
    this.quantidadeMax,
  });

  PedidoFiltro comPeriodo(PeriodoPedido periodo, [IntervaloDatas? personalizado]) => PedidoFiltro(
        periodo: periodo,
        personalizado: periodo == PeriodoPedido.personalizado ? personalizado : null,
        valorMin: valorMin,
        valorMax: valorMax,
        quantidadeMin: quantidadeMin,
        quantidadeMax: quantidadeMax,
      );

  PedidoFiltro comValor(double? min, double? max) => PedidoFiltro(
        periodo: periodo,
        personalizado: personalizado,
        valorMin: min,
        valorMax: max,
        quantidadeMin: quantidadeMin,
        quantidadeMax: quantidadeMax,
      );

  PedidoFiltro comQuantidade(int? min, int? max) => PedidoFiltro(
        periodo: periodo,
        personalizado: personalizado,
        valorMin: valorMin,
        valorMax: valorMax,
        quantidadeMin: min,
        quantidadeMax: max,
      );

  /// Período efetivo para [agora]. `null` quando não há filtro de data.
  /// "Últimos 7 dias" = hoje e os 6 dias anteriores (7 dias de calendário).
  IntervaloDatas? intervalo(DateTime agora) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return switch (periodo) {
      PeriodoPedido.todos => null,
      PeriodoPedido.hoje => IntervaloDatas(hoje, hoje),
      PeriodoPedido.ultimos7Dias => IntervaloDatas(DateTime(hoje.year, hoje.month, hoje.day - 6), hoje),
      PeriodoPedido.ultimos30Dias => IntervaloDatas(DateTime(hoje.year, hoje.month, hoje.day - 29), hoje),
      PeriodoPedido.personalizado => personalizado,
    };
  }

  bool get temData =>
      periodo != PeriodoPedido.todos && (periodo != PeriodoPedido.personalizado || personalizado != null);
  bool get temValor => valorMin != null || valorMax != null;
  bool get temQuantidade => quantidadeMin != null || quantidadeMax != null;

  /// Quantos grupos de filtro estão ativos (badge do botão).
  int get ativos => [temData, temValor, temQuantidade].where((a) => a).length;

  bool get temFiltroAtivo => ativos > 0;

  /// Mensagem de erro quando o filtro não faz sentido; `null` se estiver ok.
  String? get erro {
    if (periodo == PeriodoPedido.personalizado && personalizado == null) {
      return 'Escolha o período personalizado';
    }
    if (personalizado != null && !personalizado!.valido) {
      return 'A data inicial não pode ser depois da final';
    }
    if (valorMin != null && valorMax != null && valorMin! > valorMax!) {
      return 'O valor mínimo não pode ser maior que o máximo';
    }
    if (quantidadeMin != null && quantidadeMax != null && quantidadeMin! > quantidadeMax!) {
      return 'A quantidade mínima não pode ser maior que a máxima';
    }
    return null;
  }

  /// Filtra [pedidos] mantendo a ordem. [totais] e [quantidades] vêm dos itens
  /// carregados de cada pedido; sem entrada no mapa, o total cai em
  /// `valorTotal` e a quantidade é desconhecida (não passa no filtro de quantidade).
  List<Pedido> aplicar(
    List<Pedido> pedidos, {
    required Map<int, double> totais,
    required Map<int, int> quantidades,
    DateTime? agora,
  }) {
    final faixa = intervalo(agora ?? DateTime.now());
    return pedidos.where((p) {
      if (faixa != null) {
        final data = p.dataPedido;
        if (data == null || !faixa.contem(data)) return false;
      }
      if (temValor) {
        // Compara em centavos para "49,90" bater com 49.9 sem erro de arredondamento.
        final total = ((totais[p.id] ?? p.valorTotal) * 100).round();
        if (valorMin != null && total < (valorMin! * 100).round()) return false;
        if (valorMax != null && total > (valorMax! * 100).round()) return false;
      }
      if (temQuantidade) {
        final qtd = quantidades[p.id];
        if (qtd == null) return false;
        if (quantidadeMin != null && qtd < quantidadeMin!) return false;
        if (quantidadeMax != null && qtd > quantidadeMax!) return false;
      }
      return true;
    }).toList();
  }
}
