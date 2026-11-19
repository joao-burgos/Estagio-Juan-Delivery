import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../carrinho/controllers/carrinho_controller.dart';
import '../models/produto.dart';
import '../services/produto_service.dart';
import '../../carrinho/widgets/carrinho_appbar_action.dart';
import 'catalogo_screen.dart' show labelCategoria, labelTipo;
import '../../../core/theme/app_colors.dart';

class ProdutoDetalheScreen extends StatefulWidget {
  final int id;
  const ProdutoDetalheScreen({super.key, required this.id});

  @override
  State<ProdutoDetalheScreen> createState() => _ProdutoDetalheScreenState();
}

class _ProdutoDetalheScreenState extends State<ProdutoDetalheScreen> {
  final service = ProdutoService();
  Produto? _produto;
  bool _carregando = true;
  String? _erro;

  /// Tempo em que o botão mostra "ADICIONADO" depois de uma adição.
  static const duracaoConfirmacao = Duration(seconds: 2);

  /// Tempo em que a mensagem de limite de estoque fica abaixo do botão.
  static const duracaoAvisoLimite = Duration(seconds: 3);

  bool _confirmando = false;
  bool _avisoLimite = false;
  Timer? _timerConfirmacao;
  Timer? _timerAvisoLimite;

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
    try {
      final produto = await service.buscarPorId(widget.id);
      if (!mounted) return;
      setState(() {
        _produto = produto;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      final mensagem = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _erro = mensagem;
        _carregando = false;
      });
    }
  }

  @override
  void dispose() {
    _timerConfirmacao?.cancel();
    _timerAvisoLimite?.cancel();
    super.dispose();
  }

  /// Sem SnackBar: a confirmação aparece no próprio botão (por
  /// [duracaoConfirmacao]) e no "pulo" do ícone do carrinho. Um novo toque
  /// nesse intervalo adiciona de novo e reinicia a confirmação.
  void _adicionarAoCarrinho(Produto produto) {
    if (!context.read<CarrinhoController>().adicionar(produto)) {
      _mostrarAvisoLimite();
      return;
    }
    _timerConfirmacao?.cancel();
    _timerAvisoLimite?.cancel();
    setState(() {
      _confirmando = true;
      _avisoLimite = false;
    });
    _timerConfirmacao = Timer(duracaoConfirmacao, () {
      if (mounted) setState(() => _confirmando = false);
    });
  }

  /// Mensagem curta em vermelho logo abaixo do botão, que some sozinha.
  void _mostrarAvisoLimite() {
    _timerAvisoLimite?.cancel();
    setState(() => _avisoLimite = true);
    _timerAvisoLimite = Timer(duracaoAvisoLimite, () {
      if (mounted) setState(() => _avisoLimite = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('DETALHES DO PRODUTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar ao catálogo',
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [CarrinhoAppBarAction()],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _erro != null
              ? _ErroView(mensagem: _erro!, onTentarNovamente: _carregar)
              : _buildConteudo(_produto!),
    );
  }

  Widget _buildConteudo(Produto p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: kPrimary.withValues(alpha: 0.1),
                        child: Icon(
                          p.isAcessorio ? Icons.local_mall_outlined : Icons.wine_bar_outlined,
                          color: kPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nome,
                              style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labelTipo(p.tipo),
                              style: const TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    'R\$ ${p.preco.toStringAsFixed(2)}',
                    style: const TextStyle(color: kPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estoque: ${p.estoque} unidade(s)',
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                  if (p.descricao != null && p.descricao!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Descrição',
                        style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(p.descricao!, style: const TextStyle(color: kTextSecondary, fontSize: 14)),
                  ],
                  const SizedBox(height: 20),
                  if (p.isVinho) ..._camposVinho(p) else if (p.isAcessorio) ..._camposAcessorio(p),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _BotaoAdicionar(
            produto: p,
            confirmando: _confirmando,
            avisoLimite: _avisoLimite,
            onAdicionar: () => _adicionarAoCarrinho(p),
            onLimite: _mostrarAvisoLimite,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('VOLTAR AO CATÁLOGO'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _camposVinho(Produto p) {
    return [
      const Text('Detalhes do vinho', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 10),
      _InfoLinha(icone: Icons.category_outlined, label: 'Categoria', valor: labelCategoria(p.categoria)),
      _InfoLinha(
          icone: Icons.flag_outlined,
          label: 'País de Origem da Uva',
          valor: (p.paisOrigem != null && p.paisOrigem!.isNotEmpty) ? p.paisOrigem! : '-'),
      _InfoLinha(icone: Icons.calendar_today_outlined, label: 'Safra', valor: p.safra?.toString() ?? '-'),
      _InfoLinha(
          icone: Icons.opacity_outlined,
          label: 'Teor alcoólico',
          valor: p.teorAlcool != null ? '${p.teorAlcool}%' : '-'),
      // Harmonização é opcional: sem ela, a linha não aparece.
      if (p.harmonizacao != null && p.harmonizacao!.trim().isNotEmpty)
        _InfoLinha(icone: Icons.restaurant_outlined, label: 'Harmonização', valor: p.harmonizacao!),
    ];
  }

  List<Widget> _camposAcessorio(Produto p) {
    return [
      const Text('Detalhes do acessório',
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 10),
      _InfoLinha(
          icone: Icons.category_outlined,
          label: 'Tipo de acessório',
          valor: (p.tipoAcessorio != null && p.tipoAcessorio!.isNotEmpty) ? p.tipoAcessorio! : '-'),
      _InfoLinha(
          icone: Icons.local_offer_outlined,
          label: 'Marca',
          valor: (p.marca != null && p.marca!.isNotEmpty) ? p.marca! : '-'),
      _InfoLinha(
          icone: Icons.build_outlined,
          label: 'Material',
          valor: (p.material != null && p.material!.isNotEmpty) ? p.material! : '-'),
    ];
  }
}

class _InfoLinha extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;

  const _InfoLinha({required this.icone, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: kTextSecondary, size: 18),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: kTextSecondary, fontSize: 13)),
          Expanded(
            child: Text(valor, style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ErroView extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentarNovamente;

  const _ErroView({required this.mensagem, required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onTentarNovamente, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      ),
    );
  }
}

/// Mensagem exibida abaixo do botão ao tentar passar do estoque.
const kMensagemLimiteEstoque = 'Limite de estoque atingido';

/// Botão de adicionar ao carrinho. Fica desabilitado quando o carrinho já tem
/// todo o estoque disponível do produto, para a quantidade não passar dele;
/// tocar nele assim mostra [kMensagemLimiteEstoque] logo abaixo (via
/// [onLimite]). Com [confirmando], mostra "ADICIONADO" com um check.
class _BotaoAdicionar extends StatelessWidget {
  final Produto produto;
  final bool confirmando;
  final bool avisoLimite;
  final VoidCallback onAdicionar;
  final VoidCallback onLimite;

  const _BotaoAdicionar({
    required this.produto,
    required this.confirmando,
    required this.avisoLimite,
    required this.onAdicionar,
    required this.onLimite,
  });

  @override
  Widget build(BuildContext context) {
    final carrinho = context.watch<CarrinhoController>();
    final pode = carrinho.podeAdicionar(produto);
    final noCarrinho = carrinho.quantidadeDe(produto);
    final String texto;
    final IconData icone;
    if (!pode) {
      texto = 'ESTOQUE MÁXIMO NO CARRINHO';
      icone = Icons.shopping_cart_outlined;
    } else if (confirmando) {
      texto = 'ADICIONADO';
      icone = Icons.check;
    } else {
      texto = 'ADICIONAR AO CARRINHO';
      icone = Icons.shopping_cart_outlined;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // O botão desabilitado não trata toques; o GestureDetector os recebe
        // para avisar que o limite do estoque foi atingido.
        GestureDetector(
          onTap: pode ? null : onLimite,
          child: ElevatedButton(
            onPressed: pode ? onAdicionar : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Row(
                key: ValueKey(texto),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone),
                  const SizedBox(width: 8),
                  Flexible(child: Text(texto)),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: avisoLimite
              ? const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    kMensagemLimiteEstoque,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kPerigo, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (noCarrinho > 0) ...[
          const SizedBox(height: 6),
          Text(
            'No carrinho: $noCarrinho de ${produto.estoque} disponível(is)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
