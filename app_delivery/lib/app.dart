import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/session/restaurar_sessao.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'main_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juan Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      // Português nos componentes do Material (ex.: seletor de datas dos filtros de pedidos).
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const TelaInicial(),
    );
  }
}

/// Primeira tela do app: confere se há uma sessão salva (ex.: depois de um F5
/// no navegador) e abre a MainScreen na aba salva ou o LoginScreen.
/// Enquanto confere com a API, mostra só uma tela de carregamento.
class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  late final Future<int?> _abaRestaurada = _restaurar();

  /// Aba salva se a sessão foi restaurada; `null` se deve ir para o login.
  Future<int?> _restaurar() async {
    if (!await restaurarSessao()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('home_tab_index') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _abaRestaurada,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Carregando();
        }
        final aba = snapshot.data;
        return aba == null ? const LoginScreen() : MainScreen(abaInicial: aba);
      },
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wine_bar, size: 64, color: kCreme),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: kCreme),
            ),
          ],
        ),
      ),
    );
  }
}
