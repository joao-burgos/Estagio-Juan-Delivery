import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_delivery/app.dart';
import 'package:front_delivery/core/session/logout.dart';
import 'package:front_delivery/core/session/sessao_usuario.dart';
import 'package:front_delivery/features/admin/screens/produto_list_screen.dart';
import 'package:front_delivery/features/auth/screens/login_screen.dart';
import 'package:front_delivery/features/carrinho/controllers/carrinho_controller.dart';
import 'package:front_delivery/features/perfil/screens/perfil_screen.dart';
import 'package:front_delivery/main_screen.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/api_falsa.dart';

/// Dados que o login grava no shared_preferences.
Map<String, Object> _salvo({String perfil = 'CLIENTE', int aba = 3}) => {
      'usuario_id': 7,
      'usuario_nome': 'Fulano',
      'usuario_email': 'fulano@juan.com',
      'usuario_perfil': perfil,
      'home_tab_index': aba,
    };

Map<String, Object?> _usuarioApi({String perfil = 'CLIENTE', bool ativo = true}) => {
      'id': 7,
      'nome': 'Fulano da API',
      'email': 'fulano@juan.com',
      'cpf': '12345678909',
      'senha': 'senha123',
      'perfil': perfil,
      'ativo': ativo,
    };

/// API que responde GET /usuarios/7 com [usuario] (ou [statusUsuario] de erro);
/// as outras chamadas recebem listas vazias.
ApiFalsa _api({Map<String, Object?>? usuario, int statusUsuario = 200}) => ApiFalsa((http.Request r) {
      if (r.method == 'GET' && r.url.path == '/usuarios/7') {
        if (statusUsuario != 200) return respostaJson({'erro': 'Usuário não encontrado'}, statusUsuario);
        return respostaJson(usuario ?? _usuarioApi());
      }
      return respostaJson(const []);
    });

/// Abre o app do zero, como acontece ao dar F5 no navegador.
Future<void> _abrirApp(WidgetTester tester, ApiFalsa api) async {
  usarTelaAlta(tester);
  await api.executar(() async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: CarrinhoController.instance, child: const MyApp()),
    );
    await tester.pumpAndSettle();
  });
}

Future<void> _esperarLoginComDadosLimpos(WidgetTester tester) async {
  expect(find.byType(LoginScreen), findsOneWidget);
  expect(find.byType(MainScreen), findsNothing);
  expect(SessaoUsuario.logado, isFalse);
  final prefs = await SharedPreferences.getInstance();
  for (final chave in chavesSessao) {
    expect(prefs.containsKey(chave), isFalse, reason: chave);
  }
}

void main() {
  setUp(() {
    SessaoUsuario.limpar();
    CarrinhoController.instance.limpar();
  });

  testWidgets('cliente salvo e ativo: abre na MainScreen, na aba salva, com o perfil da API', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo(aba: 3));
    final api = _api();

    await _abrirApp(tester, api);

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(PerfilScreen), findsOneWidget);
    expect(SessaoUsuario.id, 7);
    expect(SessaoUsuario.perfil, 'CLIENTE');
    expect(SessaoUsuario.nome, 'Fulano da API');
    expect(api.requisicoes.where((r) => r.url.path == '/usuarios/7'), hasLength(1));
  });

  testWidgets('admin salvo e ativo: abre na aba Produtos', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo(perfil: 'ADMIN', aba: 1));
    final api = _api(usuario: _usuarioApi(perfil: 'ADMIN'));

    await _abrirApp(tester, api);

    expect(find.byType(ProdutoListScreen), findsOneWidget);
    expect(SessaoUsuario.isAdmin, isTrue);
  });

  testWidgets('cliente com perfil trocado para ADMIN no navegador continua CLIENTE', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo(perfil: 'ADMIN', aba: 1));
    final api = _api(usuario: _usuarioApi(perfil: 'CLIENTE'));

    await _abrirApp(tester, api);

    expect(SessaoUsuario.perfil, 'CLIENTE');
    expect(find.text('Usuários'), findsNothing);
    expect(find.text('Busca'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('usuario_perfil'), 'CLIENTE');
  });

  testWidgets('usuário inativo: abre no login e limpa os dados salvos', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo());
    final api = _api(usuario: _usuarioApi(ativo: false));

    await _abrirApp(tester, api);

    await _esperarLoginComDadosLimpos(tester);
  });

  testWidgets('usuário inexistente: abre no login e limpa os dados salvos', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo());
    final api = _api(statusUsuario: 404);

    await _abrirApp(tester, api);

    await _esperarLoginComDadosLimpos(tester);
  });

  testWidgets('API fora do ar: abre no login e limpa os dados salvos', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo());
    final api = ApiFalsa((http.Request r) => throw http.ClientException('Connection refused'));

    await _abrirApp(tester, api);

    await _esperarLoginComDadosLimpos(tester);
  });

  testWidgets('sem nada salvo: abre no login sem chamar a API', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _api();

    await _abrirApp(tester, api);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(api.requisicoes, isEmpty);
  });

  testWidgets('enquanto confere a sessão mostra o carregamento, não o login', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo());
    final api = _api();
    usarTelaAlta(tester);

    await api.executar(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: CarrinhoController.instance, child: const MyApp()),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      await tester.pumpAndSettle();
    });
    expect(find.byType(MainScreen), findsOneWidget);
  });

  testWidgets('logout depois de restaurar limpa os dados e volta ao login sem volta', (tester) async {
    SharedPreferences.setMockInitialValues(_salvo(aba: 3));
    final api = _api();
    await _abrirApp(tester, api);

    await api.executar(() async {
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sair'));
      await tester.pumpAndSettle();
    });

    await _esperarLoginComDadosLimpos(tester);
    expect(Navigator.of(tester.element(find.byType(LoginScreen))).canPop(), isFalse);

    // F5 depois do logout continua no login.
    await tester.pumpWidget(const SizedBox());
    await _abrirApp(tester, api);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
