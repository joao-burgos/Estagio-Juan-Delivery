import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Linha discreta acima da lista: "X resultados" e, se houver algum filtro
/// ativo, o link "Limpar filtros".
class ResultadosHeader extends StatelessWidget {
  final int total;
  final bool filtrosAtivos;
  final VoidCallback onLimpar;

  const ResultadosHeader({
    super.key,
    required this.total,
    required this.filtrosAtivos,
    required this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Text(
              total == 1 ? '1 resultado' : '$total resultados',
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const Spacer(),
            if (filtrosAtivos)
              TextButton(
                onPressed: onLimpar,
                style: TextButton.styleFrom(
                  foregroundColor: kPrimary,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Limpar filtros'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio quando os filtros não encontram nada.
class SemResultados extends StatelessWidget {
  final VoidCallback onLimpar;
  final String mensagem;

  const SemResultados({
    super.key,
    required this.onLimpar,
    this.mensagem = 'Nenhum resultado para os filtros aplicados',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: kPrimary),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onLimpar,
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}
