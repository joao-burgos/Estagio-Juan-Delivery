import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogo de confirmação padrão do app (card branco, cantos de 12px, título
/// vinho e dois botões de texto). Retorna `true` só se o usuário tocar no
/// botão de confirmar; "voltar", tocar fora ou o botão de voltar do sistema
/// retornam `false`.
Future<bool> mostrarDialogoConfirmacao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String textoConfirmar,
  required Color corConfirmar,
  String textoVoltar = 'Cancelar',
}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(titulo, style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600)),
      content: Text(mensagem, style: const TextStyle(color: kTextPrimary)),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: kTextSecondary),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(textoVoltar),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: corConfirmar),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoConfirmar, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return confirmar == true;
}
