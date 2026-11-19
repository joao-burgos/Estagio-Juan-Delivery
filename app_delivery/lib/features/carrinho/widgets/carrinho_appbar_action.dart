import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/carrinho_controller.dart';
import '../screens/carrinho_screen.dart';

/// Ícone de carrinho com badge de quantidade, usado na AppBar de
/// InicioScreen, CatalogoScreen (Busca) e ProdutoDetalheScreen. Ao tocar,
/// navega para a CarrinhoScreen.
///
/// Quando a quantidade de itens aumenta, o ícone dá um "pulo" curto (cresce
/// ~25% e volta em ~300 ms). É só um efeito visual (ScaleTransition): não
/// muda o tamanho nem a posição do ícone na AppBar.
class CarrinhoAppBarAction extends StatefulWidget {
  const CarrinhoAppBarAction({super.key});

  static const duracaoPulo = Duration(milliseconds: 300);

  @override
  State<CarrinhoAppBarAction> createState() => _CarrinhoAppBarActionState();
}

class _CarrinhoAppBarActionState extends State<CarrinhoAppBarAction> with SingleTickerProviderStateMixin {
  late final AnimationController _pulo = AnimationController(vsync: this, duration: CarrinhoAppBarAction.duracaoPulo);
  late final Animation<double> _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
  ]).animate(_pulo);

  CarrinhoController? _carrinho;
  int _ultimaQuantidade = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final carrinho = Provider.of<CarrinhoController>(context, listen: false);
    if (!identical(carrinho, _carrinho)) {
      _carrinho?.removeListener(_aoMudarCarrinho);
      _carrinho = carrinho..addListener(_aoMudarCarrinho);
      _ultimaQuantidade = carrinho.totalItens;
    }
  }

  void _aoMudarCarrinho() {
    final quantidade = _carrinho!.totalItens;
    if (quantidade > _ultimaQuantidade && mounted) _pulo.forward(from: 0);
    _ultimaQuantidade = quantidade;
  }

  @override
  void dispose() {
    _carrinho?.removeListener(_aoMudarCarrinho);
    _pulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarrinhoController>(
      builder: (context, carrinho, _) {
        final quantidade = carrinho.totalItens;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ScaleTransition(
            scale: _escala,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  tooltip: 'Carrinho',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CarrinhoScreen()),
                  ),
                ),
                if (quantidade > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IgnorePointer(
                      child: Container(
                        key: const ValueKey('badge-carrinho'),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: const BoxDecoration(color: kPerigo, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          quantidade > 99 ? '99+' : '$quantidade',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
