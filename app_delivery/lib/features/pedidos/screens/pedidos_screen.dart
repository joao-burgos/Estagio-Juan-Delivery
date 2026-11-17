import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../filters/pedido_filtro.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../../../core/session/sessao_usuario.dart';
import 'detalhes_pedido_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/filtro_chip.dart';
import '../../../core/widgets/paginacao.dart';
import '../../../core/widgets/painel_filtros.dart';
import '../../../core/widgets/resultados_header.dart';

const _kHistoricoBg = Color(0xFFF5F5F5);

const _kStatusEmAberto = ['PENDENTE', 'CONFIRMADO', 'EM_PREPARO', 'EM_ENTREGA'];
const _kStatusHistorico = ['ENTREGUE', 'CANCELADO'];

const _kStatusLabels = {
  'PENDENTE': 'Pendente',
  'CONFIRMADO': 'Confirmado',
  'EM_PREPARO': 'Em preparo',
  'EM_ENTREGA': 'Em entrega',
  'ENTREGUE': 'Entregue',
  'CANCELADO': 'Cancelado',
};

const _kStatusCores = {
  'PENDENTE': Color(0xFFEF6C00), // laranja
  'CONFIRMADO': Color(0xFF1565C0), // azul
  'EM_PREPARO': Color(0xFF6A1B9A), // roxo
  'EM_ENTREGA': Color(0xFFF9A825), // amarelo
  'ENTREGUE': Color(0xFF2E7D32), // verde
  'CANCELADO': Color(0xFFC62828), // vermelho
};

/// Aba "Pedidos" do cliente: busca os pedidos do usuário logado (GET
/// /pedidos/usuario/{usuarioId}) e os separa em duas sub-abas — Em Aberto
/// (status ainda em andamento) e Histórico (pedidos encerrados).
class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> with SingleTickerProviderStateMixin {
  final _service = PedidoService();
  late final TabController _tabController;

  List<Pedido> _pedidos = [];
  // O backend não recalcula valorTotal do pedido ao adicionar itens (fica
  // sempre em 0 — ver comentário em DetalhesPedidoScreen), então o total de
  // cada card é somado a partir dos itens de cada pedido.
  final Map<int, double> _totais = {};
  // Soma das quantidades dos itens de cada pedido (para o filtro de quantidade).
  final Map<int, int> _quantidades = {};
  bool _carregando = true;

  // Filtro local, aplicado às duas abas antes da paginação.
  PedidoFiltro _filtro = const PedidoFiltro();

  // Paginação só na interface, uma página atual por aba (começam em 1).
  int _paginaEmAberto = 1;
  int _paginaHistorico = 1;
  final _scrollEmAberto = ScrollController();
  final _scrollHistorico = ScrollController();

  // Campos do painel de filtros (ficam com a tela para sobreviver à animação de fechar o painel).
  final _valorMin = TextEditingController();
  final _valorMax = TextEditingController();
  final _qtdMin = TextEditingController();
  final _qtdMax = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(_aoTrocarAba);
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollEmAberto.dispose();
    _scrollHistorico.dispose();
    for (final c in [_valorMin, _valorMax, _qtdMin, _qtdMax]) {
      c.dispose();
    }
    super.dispose();
  }

  int _abaAtual = 0;

  /// Trocar de aba (por toque ou arrastando) volta as duas para a página 1.
  void _aoTrocarAba() {
    if (_tabController.index == _abaAtual) return;
    setState(() {
      _abaAtual = _tabController.index;
      _paginaEmAberto = 1;
      _paginaHistorico = 1;
    });
  }

  void _irParaPagina(ScrollController scroll, VoidCallback mudar) {
    setState(mudar);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  /// Pedidos que passam no filtro atual (base das duas abas).
  List<Pedido> get _filtrados => _filtro.aplicar(_pedidos, totais: _totais, quantidades: _quantidades);

  List<Pedido> get _emAberto => _filtrados.where((p) => _kStatusEmAberto.contains(p.status)).toList();

  List<Pedido> get _historico {
    final lista = _filtrados.where((p) => _kStatusHistorico.contains(p.status)).toList();
    lista.sort((a, b) {
      final dataA = a.dataPedido;
      final dataB = b.dataPedido;
      if (dataA == null || dataB == null) return 0;
      return dataB.compareTo(dataA);
    });
    return lista;
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final pedidos = await _service.listarPorUsuario(SessaoUsuario.id!);
      final totais = <int, double>{};
      final quantidades = <int, int>{};
      await Future.wait(pedidos.map((p) async {
        try {
          final itens = await _service.listarItensPorPedido(p.id);
          totais[p.id] = itens.fold(0.0, (soma, item) => soma + item.subtotal);
          quantidades[p.id] = itens.fold(0, (soma, item) => soma + item.quantidade);
        } catch (_) {
          totais[p.id] = p.valorTotal;
        }
      }));
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _totais
          ..clear()
          ..addAll(totais);
        _quantidades
          ..clear()
          ..addAll(quantidades);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      final mensagem = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _abrirDetalhes(int pedidoId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalhesPedidoScreen(pedidoId: pedidoId)),
    ).then((_) {
      if (!mounted) return;
      _carregar();
    });
  }

  /// Troca o filtro e volta as duas abas para a página 1.
  void _aplicarFiltro(PedidoFiltro filtro) {
    setState(() {
      _filtro = filtro;
      _paginaEmAberto = 1;
      _paginaHistorico = 1;
    });
    for (final scroll in [_scrollEmAberto, _scrollHistorico]) {
      if (scroll.hasClients) scroll.jumpTo(0);
    }
  }

  void _limparFiltros() => _aplicarFiltro(const PedidoFiltro());

  /// Abre o seletor de período em português e nas cores do app.
  Future<IntervaloDatas?> _escolherPeriodo(IntervaloDatas? atual) async {
    final hoje = DateTime.now();
    final ultimoDia = DateTime(hoje.year, hoje.month, hoje.day);
    final escolhido = await showDateRangePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: ultimoDia,
      initialDateRange:
          atual == null || atual.fim.isAfter(ultimoDia) ? null : DateTimeRange(start: atual.inicio, end: atual.fim),
      helpText: 'Selecione o período',
      saveText: 'Aplicar', // modo calendário
      confirmText: 'Aplicar', // modo digitação
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    return escolhido == null ? null : IntervaloDatas(escolhido.start, escolhido.end);
  }

  Future<void> _abrirFiltros() async {
    String texto(num? v, {bool decimal = false}) =>
        v == null ? '' : (decimal ? v.toStringAsFixed(2).replaceAll('.', ',') : '$v');
    _valorMin.text = texto(_filtro.valorMin, decimal: true);
    _valorMax.text = texto(_filtro.valorMax, decimal: true);
    _qtdMin.text = texto(_filtro.quantidadeMin);
    _qtdMax.text = texto(_filtro.quantidadeMax);

    final escolhido = await abrirPainelFiltros<PedidoFiltro>(
      context: context,
      rascunho: _filtro,
      limpar: (_) => const PedidoFiltro(),
      validar: (f) => f.erro,
      construir: (f, atualizar) {
        final intervalo = f.intervalo(DateTime.now());
        return [
          SecaoFiltro(
            titulo: 'Período',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in PeriodoPedido.values)
                    FiltroChip(
                      label: p.label,
                      selecionado: f.periodo == p,
                      onTap: () async {
                        if (p != PeriodoPedido.personalizado) {
                          atualizar(f.comPeriodo(p));
                          return;
                        }
                        final periodo = await _escolherPeriodo(f.personalizado);
                        // Cancelou o seletor: mantém o que estava.
                        if (periodo != null) atualizar(f.comPeriodo(p, periodo));
                      },
                    ),
                ]),
                if (intervalo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    intervalo.rotulo,
                    key: const ValueKey('rotulo-periodo'),
                    style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          SecaoFiltro(
            titulo: 'Valor total',
            child: _CamposFaixa(
              rotuloMin: 'Valor mínimo',
              rotuloMax: 'Valor máximo',
              prefixo: 'R\$ ',
              decimal: true,
              min: _valorMin,
              max: _valorMax,
              onChanged: () => atualizar(f.comValor(lerValor(_valorMin.text), lerValor(_valorMax.text))),
            ),
          ),
          SecaoFiltro(
            titulo: 'Quantidade de itens',
            child: _CamposFaixa(
              rotuloMin: 'Mínimo de itens',
              rotuloMax: 'Máximo de itens',
              min: _qtdMin,
              max: _qtdMax,
              onChanged: () => atualizar(f.comQuantidade(int.tryParse(_qtdMin.text), int.tryParse(_qtdMax.text))),
            ),
          ),
          const SizedBox(height: 8),
          const DicaFiltro('Os filtros valem para Em Aberto e Histórico.'),
        ];
      },
    );

    if (escolhido != null && mounted) _aplicarFiltro(escolhido);
  }

  /// Resumo legível dos filtros ativos, ex.: "01/11/2026 – 17/11/2026 · até R$ 200,00".
  String _resumoFiltros() {
    String faixa(String? min, String? max) => switch ((min, max)) {
          (String a, String b) => '$a a $b',
          (String a, null) => 'a partir de $a',
          (null, String b) => 'até $b',
          _ => '',
        };
    final partes = <String>[
      if (_filtro.temData) _filtro.intervalo(DateTime.now())!.rotulo,
      if (_filtro.temValor)
        faixa(
          _filtro.valorMin == null ? null : formatarReais(_filtro.valorMin!),
          _filtro.valorMax == null ? null : formatarReais(_filtro.valorMax!),
        ),
      if (_filtro.temQuantidade) '${faixa(_filtro.quantidadeMin?.toString(), _filtro.quantidadeMax?.toString())} itens',
    ];
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Meus Pedidos'),
        backgroundColor: kPrimary,
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _carregando ? null : _abrirFiltros,
            icon: Badge(
              isLabelVisible: _filtro.temFiltroAtivo,
              label: Text('${_filtro.ativos}'),
              backgroundColor: Colors.white,
              textColor: kPrimary,
              child: const Icon(Icons.tune, color: Colors.white),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: kCreme,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Em Aberto'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(
              children: [
                if (_filtro.temFiltroAtivo) _buildFiltrosAtivos(),
                Expanded(
                  child: RefreshIndicator(
                    color: kPrimary,
                    onRefresh: _carregar,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEmAberto(),
                        _buildHistorico(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Faixa acima das abas com o resumo dos filtros e o link "Limpar filtros".
  Widget _buildFiltrosAtivos() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 16, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _resumoFiltros(),
              key: const ValueKey('resumo-filtros'),
              style: const TextStyle(color: kTextPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _limparFiltros,
            style: TextButton.styleFrom(
              foregroundColor: kPrimary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: const Text('Limpar filtros'),
          ),
        ],
      ),
    );
  }

  /// Estado vazio de uma aba quando há filtro ativo e nada bate com ele.
  Widget _buildSemResultados() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: SemResultados(
            mensagem: 'Nenhum pedido encontrado com esses filtros',
            onLimpar: _limparFiltros,
          ),
        ),
      ),
    );
  }

  Widget _buildEmAberto() {
    final pedidos = _emAberto;
    if (pedidos.isEmpty && _filtro.temFiltroAtivo) return _buildSemResultados();
    if (pedidos.isEmpty) {
      return _buildVazio(
        icone: Icons.inventory_2_outlined,
        mensagem: 'Nenhum pedido em aberto',
      );
    }
    // Se a página ficou vazia (ex.: pedido cancelado foi para o histórico), cai na anterior.
    _paginaEmAberto = paginaValida(_paginaEmAberto, pedidos.length);
    return ListView(
      controller: _scrollEmAberto,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        for (final p in fatiarPagina(pedidos, _paginaEmAberto))
          _CardPedido(
            pedido: p,
            total: _totais[p.id] ?? p.valorTotal,
            onVerDetalhes: () => _abrirDetalhes(p.id),
          ),
        Paginacao(
          totalItens: pedidos.length,
          paginaAtual: _paginaEmAberto,
          onPaginaChanged: (n) => _irParaPagina(_scrollEmAberto, () => _paginaEmAberto = n),
        ),
      ],
    );
  }

  Widget _buildHistorico() {
    final pedidos = _historico;
    if (pedidos.isEmpty && _filtro.temFiltroAtivo) return _buildSemResultados();
    if (pedidos.isEmpty) {
      return _buildVazio(
        icone: Icons.list_alt_outlined,
        mensagem: 'Nenhum pedido no histórico',
      );
    }
    _paginaHistorico = paginaValida(_paginaHistorico, pedidos.length);
    return ListView(
      controller: _scrollHistorico,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        for (final p in fatiarPagina(pedidos, _paginaHistorico))
          _CardPedido(
            pedido: p,
            total: _totais[p.id] ?? p.valorTotal,
            encerrado: true,
            onVerDetalhes: () => _abrirDetalhes(p.id),
          ),
        Paginacao(
          totalItens: pedidos.length,
          paginaAtual: _paginaHistorico,
          onPaginaChanged: (n) => _irParaPagina(_scrollHistorico, () => _paginaHistorico = n),
        ),
      ],
    );
  }

  Widget _buildVazio({required IconData icone, required String mensagem}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 56, color: kTextSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(mensagem, style: const TextStyle(color: kTextSecondary, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Valor em reais: até 7 dígitos inteiros e 2 decimais, com vírgula ou ponto.
/// Uma edição que deixaria o texto fora desse formato é ignorada.
final _kFormatoValor = TextInputFormatter.withFunction(
  (antigo, novo) => RegExp(r'^\d{0,7}([.,]\d{0,2})?$').hasMatch(novo.text) ? novo : antigo,
);

/// Dois campos lado a lado (mínimo e máximo), opcionais. Com [decimal], aceita
/// vírgula ou ponto e até 2 casas; sem, só números inteiros.
class _CamposFaixa extends StatelessWidget {
  final String rotuloMin;
  final String rotuloMax;
  final String? prefixo;
  final bool decimal;
  final TextEditingController min;
  final TextEditingController max;
  final VoidCallback onChanged;

  const _CamposFaixa({
    required this.rotuloMin,
    required this.rotuloMax,
    required this.min,
    required this.max,
    required this.onChanged,
    this.prefixo,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget campo(String rotulo, TextEditingController controller) => Expanded(
          child: TextField(
            key: ValueKey(rotulo),
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              decimal ? _kFormatoValor : FilteringTextInputFormatter.digitsOnly,
            ],
            cursorColor: kPrimary,
            decoration: InputDecoration(
              labelText: rotulo,
              prefixText: prefixo,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
            ),
          ),
        );

    return Row(
      children: [
        campo(rotuloMin, min),
        const SizedBox(width: 12),
        campo(rotuloMax, max),
      ],
    );
  }
}

class _CardPedido extends StatelessWidget {
  final Pedido pedido;
  final double total;
  final bool encerrado;
  final VoidCallback onVerDetalhes;

  const _CardPedido({
    required this.pedido,
    required this.total,
    required this.onVerDetalhes,
    this.encerrado = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = _kStatusCores[pedido.status] ?? kTextSecondary;
    final label = _kStatusLabels[pedido.status] ?? pedido.status;
    final data = pedido.dataPedido != null ? _formatarData(pedido.dataPedido!) : '-';

    return InkWell(
      onTap: onVerDetalhes,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: encerrado ? _kHistoricoBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${pedido.id}',
                  style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(data, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R\$ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!encerrado)
                  TextButton(
                    onPressed: onVerDetalhes,
                    style: TextButton.styleFrom(foregroundColor: kPrimary),
                    child: const Text('Ver detalhes', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year} $hora:$minuto';
  }
}
