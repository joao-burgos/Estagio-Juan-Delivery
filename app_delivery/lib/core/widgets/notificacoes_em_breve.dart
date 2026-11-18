import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Aviso exibido pelos atalhos de notificações (sino da tela inicial e item
/// "Notificações" do Perfil) enquanto a funcionalidade não existe.
void mostrarNotificacoesEmBreve(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Notificações em breve'),
        backgroundColor: kPrimary,
        duration: Duration(seconds: 2),
      ),
    );
}
