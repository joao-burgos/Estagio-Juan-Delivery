import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Itens por página das listas do app.
const kItensPorPagina = 10;

/// Quantidade de páginas para [total] itens (no mínimo 1).
int totalPaginas(int total, [int itensPorPagina = kItensPorPagina]) => total <= 0 ? 1 : (total / itensPorPagina).ceil();

/// Mantém [pagina] (começa em 1) dentro das páginas existentes. Se a página
/// atual ficou vazia (ex.: o último item dela foi removido), cai na anterior.
int paginaValida(int pagina, int total, [int itensPorPagina = kItensPorPagina]) =>
    pagina.clamp(1, totalPaginas(total, itensPorPagina));

/// Os itens de [lista] que aparecem na [pagina] (começa em 1).
List<T> fatiarPagina<T>(List<T> lista, int pagina, [int itensPorPagina = kItensPorPagina]) {
  final inicio = (paginaValida(pagina, lista.length, itensPorPagina) - 1) * itensPorPagina;
  return lista.sublist(inicio, math.min(inicio + itensPorPagina, lista.length));
}

/// Números (e reticências, como `null`) exibidos para [atual] de [total]
/// páginas. Até 7 páginas mostra todas; acima disso sempre 7 posições, ex.:
/// `1 2 3 4 5 … 12`, `1 … 4 5 6 … 12`, `1 … 8 9 10 11 12`.
List<int?> paginasVisiveis(int atual, int total) {
  if (total <= 7) return [for (var i = 1; i <= total; i++) i];
  if (atual <= 4) return [1, 2, 3, 4, 5, null, total];
  if (atual >= total - 3) return [1, null, for (var i = total - 4; i <= total; i++) i];
  return [1, null, atual - 1, atual, atual + 1, null, total];
}

/// Controle de paginação `‹ 1 2 3 ›`, feito só na interface: a tela fatia a
/// lista que já tem (ver [fatiarPagina]). Não aparece com [itensPorPagina]
/// itens ou menos.
class Paginacao extends StatelessWidget {
  final int totalItens;

  /// Página exibida, começando em 1.
  final int paginaAtual;
  final int itensPorPagina;
  final ValueChanged<int> onPaginaChanged;

  const Paginacao({
    super.key,
    required this.totalItens,
    required this.paginaAtual,
    required this.onPaginaChanged,
    this.itensPorPagina = kItensPorPagina,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItens <= itensPorPagina) return const SizedBox.shrink();
    final total = totalPaginas(totalItens, itensPorPagina);
    final atual = paginaValida(paginaAtual, totalItens, itensPorPagina);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // scaleDown: em telas estreitas encolhe em vez de estourar a largura.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Seta(
              icone: Icons.chevron_left,
              tooltip: 'Página anterior',
              onPressed: atual > 1 ? () => onPaginaChanged(atual - 1) : null,
            ),
            for (final p in paginasVisiveis(atual, total))
              if (p == null)
                const SizedBox(
                  width: 28,
                  child: Text('…', textAlign: TextAlign.center, style: TextStyle(color: kTextSecondary, fontSize: 15)),
                )
              else
                _BotaoPagina(
                  key: ValueKey('pagina-$p'),
                  numero: p,
                  selecionada: p == atual,
                  onTap: () => onPaginaChanged(p),
                ),
            _Seta(
              icone: Icons.chevron_right,
              tooltip: 'Próxima página',
              onPressed: atual < total ? () => onPaginaChanged(atual + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Seta extends StatelessWidget {
  final IconData icone;
  final String tooltip;
  final VoidCallback? onPressed;

  const _Seta({required this.icone, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icone),
      tooltip: tooltip,
      onPressed: onPressed,
      color: kPrimary,
      disabledColor: kTextSecondary.withValues(alpha: 0.35),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _BotaoPagina extends StatelessWidget {
  final int numero;
  final bool selecionada;
  final VoidCallback onTap;

  const _BotaoPagina({super.key, required this.numero, required this.selecionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selecionada ? kPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Tocar na página atual não faz nada.
          onTap: selecionada ? null : onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Text(
                '$numero',
                style: TextStyle(
                  color: selecionada ? Colors.white : kPrimary,
                  fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
