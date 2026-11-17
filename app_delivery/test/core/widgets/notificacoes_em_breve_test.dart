import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/core/session/sessao_usuario.dart';
import 'package:front_delivery/features/perfil/screens/perfil_screen.dart';

void main() {
  setUp(() => SessaoUsuario.salvar(id: 7, nome: 'Fulano', email: 'fulano@juan.com', perfil: 'CLIENTE'));
  tearDown(SessaoUsuario.limpar);

  testWidgets('item Notificações do Perfil mostra "Notificações em breve"', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PerfilScreen())));
    expect(find.text('Notificações em breve'), findsNothing);

    await tester.tap(find.text('Notificações'));
    await tester.pump();

    expect(find.text('Notificações em breve'), findsOneWidget);
  });
}
