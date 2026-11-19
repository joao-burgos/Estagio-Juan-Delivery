import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/perfil/services/usuario_service.dart';
import 'logout.dart';
import 'sessao_usuario.dart';

/// Tempo máximo esperando a API confirmar o usuário salvo ao abrir o app.
const tempoLimiteRestaurarSessao = Duration(seconds: 8);

/// Tenta restaurar a sessão salva no shared_preferences (ex.: depois de um F5
/// no navegador).
///
/// Só o id salvo é usado: o usuário é conferido na API (GET /usuarios/{id}) e a
/// [SessaoUsuario] é preenchida com o que a API devolveu, principalmente o
/// perfil, porque o armazenamento local pode ser editado no navegador.
///
/// Retorna `true` se a sessão foi restaurada. Se não há usuário salvo, se ele
/// não existe, está inativo ou a API não respondeu, limpa os dados salvos e
/// retorna `false`.
Future<bool> restaurarSessao({UsuarioService? service}) async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getInt('usuario_id');
  if (id == null || id <= 0) {
    await _limparDadosSalvos(prefs);
    return false;
  }

  try {
    final usuario = await (service ?? UsuarioService()).buscarPorId(id).timeout(tempoLimiteRestaurarSessao);
    final perfil = usuario.perfil;
    if (!usuario.ativo || usuario.id != id || (perfil != 'ADMIN' && perfil != 'CLIENTE')) {
      await _limparDadosSalvos(prefs);
      return false;
    }
    SessaoUsuario.salvar(id: id, nome: usuario.nome, email: usuario.email, perfil: perfil);
    await prefs.setString('usuario_nome', usuario.nome);
    await prefs.setString('usuario_email', usuario.email);
    await prefs.setString('usuario_perfil', perfil!);
    return true;
  } catch (_) {
    // Usuário inexistente (404/400), erro do servidor ou API fora do ar.
    await _limparDadosSalvos(prefs);
    return false;
  }
}

Future<void> _limparDadosSalvos(SharedPreferences prefs) async {
  SessaoUsuario.limpar();
  for (final chave in chavesSessao) {
    await prefs.remove(chave);
  }
}
