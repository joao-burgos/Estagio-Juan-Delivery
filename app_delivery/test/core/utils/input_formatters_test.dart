import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_delivery/core/utils/input_formatters.dart';

TextEditingValue _valor(String texto) =>
    TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));

/// Simula a digitação de [entrada], caractere a caractere, no fim do campo.
TextEditingValue _digitar(TextInputFormatter f, String entrada, {String inicial = ''}) {
  var atual = _valor(inicial);
  for (final c in entrada.split('')) {
    atual = f.formatEditUpdate(atual, _valor(atual.text + c));
  }
  return atual;
}

/// Simula um backspace com o cursor no fim do campo.
TextEditingValue _backspace(TextInputFormatter f, TextEditingValue atual) {
  final t = atual.text;
  return f.formatEditUpdate(atual, _valor(t.substring(0, t.length - 1)));
}

/// Simula um backspace com o cursor na posição [cursor].
TextEditingValue _backspaceEm(TextInputFormatter f, String texto, int cursor) => f.formatEditUpdate(
      TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: cursor)),
      TextEditingValue(
        text: texto.substring(0, cursor - 1) + texto.substring(cursor),
        selection: TextSelection.collapsed(offset: cursor - 1),
      ),
    );

/// Simula a tecla Delete (apaga para a frente) com o cursor na posição [cursor].
TextEditingValue _deleteEm(TextInputFormatter f, String texto, int cursor) => f.formatEditUpdate(
      TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: cursor)),
      TextEditingValue(
        text: texto.substring(0, cursor) + texto.substring(cursor + 1),
        selection: TextSelection.collapsed(offset: cursor),
      ),
    );

/// Simula digitar [c] com o cursor na posição [cursor].
TextEditingValue _digitarEm(TextInputFormatter f, String texto, int cursor, String c) => f.formatEditUpdate(
      TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: cursor)),
      TextEditingValue(
        text: texto.substring(0, cursor) + c + texto.substring(cursor),
        selection: TextSelection.collapsed(offset: cursor + 1),
      ),
    );

/// Segura o backspace no fim do campo até ele esvaziar; devolve quantas vezes apagou.
int _apagarTudo(TextInputFormatter f, TextEditingValue v) {
  var vezes = 0;
  while (v.text.isNotEmpty && vezes < 30) {
    final anterior = v.text;
    v = _backspace(f, v);
    vezes++;
    expect(v.text.length, lessThan(anterior.length), reason: 'backspace travou em "$anterior"');
  }
  expect(v.text, '');
  return vezes;
}

/// Simula colar [colado] em um campo vazio.
TextEditingValue _colar(TextInputFormatter f, String colado) => f.formatEditUpdate(_valor(''), _valor(colado));

void main() {
  group('TelefoneInputFormatter', () {
    final f = TelefoneInputFormatter();

    test('formata progressivamente enquanto digita', () {
      expect(_digitar(f, '4').text, '(4');
      expect(_digitar(f, '43').text, '(43');
      expect(_digitar(f, '439').text, '(43) 9');
      expect(_digitar(f, '4399999').text, '(43) 99999');
      expect(_digitar(f, '43999998888').text, '(43) 99999-8888');
      expect(_digitar(f, '4333334444').text, '(43) 3333-4444');
    });

    test('reposiciona o hífen ao digitar o 11º dígito', () {
      final fixo = _digitar(f, '4333334444');
      expect(fixo.text, '(43) 3333-4444');
      expect(_digitar(f, '5', inicial: fixo.text).text, '(43) 33334-4445');
    });

    test('limita a 11 dígitos', () {
      expect(_digitar(f, '439999988887777').text, '(43) 99999-8888');
    });

    test('ignora letras e símbolos', () {
      expect(_digitar(f, '4a3b9#9*').text, '(43) 99');
      expect(_digitar(f, 'abc').text, '');
    });

    test('cursor fica sempre no final', () {
      final v = _digitar(f, '43999998888');
      expect(v.selection, TextSelection.collapsed(offset: v.text.length));
    });

    test('backspace apaga até esvaziar sem travar nos símbolos', () {
      var v = _digitar(f, '43999998888');
      final esperados = [
        '(43) 9999-9888',
        '(43) 9999-988',
        '(43) 9999-98',
        '(43) 99999',
        '(43) 9999',
        '(43) 999',
        '(43) 99',
        '(43) 9',
        '(43',
        '(4',
        '',
      ];
      for (final e in esperados) {
        v = _backspace(f, v);
        expect(v.text, e);
        expect(v.selection.baseOffset, v.text.length);
      }
    });

    test('backspace sobre um símbolo remove também o dígito anterior', () {
      // Hífen apagado em "(43) 1234-56": remove o "4" que vinha antes dele.
      final antes = _valor('(43) 1234-56');
      final depois = f.formatEditUpdate(
        antes,
        const TextEditingValue(text: '(43) 123456', selection: TextSelection.collapsed(offset: 9)),
      );
      expect(depois.text, '(43) 12356');
      // O cursor fica onde estava (depois do "3"), não pula para o fim.
      expect(depois.selection.baseOffset, '(43) 123'.length);

      // Parêntese de "(4" apagado com o cursor logo após ele.
      final soDdd = f.formatEditUpdate(
        _valor('(43'),
        const TextEditingValue(text: '43', selection: TextSelection.collapsed(offset: 0)),
      );
      expect(soDdd.text, '(43');
    });

    test('colar valor formatado ou só números', () {
      expect(_colar(f, '(43) 99999-8888').text, '(43) 99999-8888');
      expect(_colar(f, '43999998888').text, '(43) 99999-8888');
      expect(_colar(f, '4333334444').text, '(43) 3333-4444');
      expect(_colar(f, '+55 (43) 3333-4444').text, '(55) 43333-3444');
    });
  });

  group('CpfInputFormatter', () {
    final f = CpfInputFormatter();

    test('formata progressivamente enquanto digita', () {
      expect(_digitar(f, '111').text, '111');
      expect(_digitar(f, '1114').text, '111.4');
      expect(_digitar(f, '1114447').text, '111.444.7');
      expect(_digitar(f, '11144477735').text, '111.444.777-35');
    });

    test('limita a 11 dígitos', () {
      expect(_digitar(f, '1114447773599').text, '111.444.777-35');
    });

    test('ignora letras e símbolos', () {
      expect(_digitar(f, '1a1b1c4!').text, '111.4');
    });

    test('cursor fica sempre no final', () {
      final v = _digitar(f, '1114447');
      expect(v.selection, TextSelection.collapsed(offset: v.text.length));
    });

    test('backspace apaga até esvaziar sem travar nos símbolos', () {
      var v = _digitar(f, '11144477735');
      final esperados = [
        '111.444.777-3',
        '111.444.777',
        '111.444.77',
        '111.444.7',
        '111.444',
        '111.44',
        '111.4',
        '111',
        '11',
        '1',
        '',
      ];
      for (final e in esperados) {
        v = _backspace(f, v);
        expect(v.text, e);
        expect(v.selection.baseOffset, v.text.length);
      }
    });

    test('backspace sobre um símbolo remove também o dígito anterior', () {
      // Hífen apagado em "111.444.777-35": remove o "7" que vinha antes dele.
      final antes = _valor('111.444.777-35');
      final depois = f.formatEditUpdate(
        antes,
        const TextEditingValue(text: '111.444.77735', selection: TextSelection.collapsed(offset: 11)),
      );
      expect(depois.text, '111.444.773-5');
      expect(depois.selection.baseOffset, '111.444.77'.length);
    });

    test('colar valor formatado ou só números', () {
      expect(_colar(f, '111.444.777-35').text, '111.444.777-35');
      expect(_colar(f, '11144477735').text, '111.444.777-35');
    });
  });

  group('CepInputFormatter', () {
    final f = CepInputFormatter();

    test('formata progressivamente enquanto digita', () {
      expect(_digitar(f, '0').text, '0');
      expect(_digitar(f, '01310').text, '01310');
      expect(_digitar(f, '013101').text, '01310-1');
      expect(_digitar(f, '01310100').text, '01310-100');
    });

    test('limita a 8 dígitos e ignora letras', () {
      expect(_digitar(f, '0131010099').text, '01310-100');
      expect(_digitar(f, '01a3b10-1').text, '01310-1');
    });

    test('backspace apaga até esvaziar sem travar no hífen', () {
      var v = _digitar(f, '01310100');
      final esperados = ['01310-10', '01310-1', '01310', '0131', '013', '01', '0', ''];
      for (final e in esperados) {
        v = _backspace(f, v);
        expect(v.text, e);
        expect(v.selection.baseOffset, v.text.length);
      }
    });

    test('backspace logo depois do hífen remove o dígito anterior', () {
      // "01310-|100": o hífen é apagado junto com o "0" antes dele.
      final v = _backspaceEm(f, '01310-100', 6);
      expect(v.text, '01311-00');
      expect(v.selection.baseOffset, 4);
    });

    test('colar valor formatado ou só números', () {
      expect(_colar(f, '01310-100').text, '01310-100');
      expect(_colar(f, '01310100').text, '01310-100');
    });

    test('formatarCep para exibição', () {
      expect(formatarCep('01310100'), '01310-100');
      expect(formatarCep('0131'), '0131');
      expect(formatarCep(null), '');
    });
  });

  group('máscaras: apagar e editar no meio', () {
    final mascaras = <String, (TextInputFormatter, String)>{
      'CEP': (CepInputFormatter(), '01310100'),
      'CPF': (CpfInputFormatter(), '11144477735'),
      'telefone celular': (TelefoneInputFormatter(), '43999998888'),
      'telefone fixo': (TelefoneInputFormatter(), '4333334444'),
    };

    mascaras.forEach((nome, dados) {
      final (f, digitos) = dados;

      test('$nome: segurar backspace no fim esvazia o campo, um dígito por vez', () {
        final vezes = _apagarTudo(f, _digitar(f, digitos));
        expect(vezes, digitos.length);
      });

      test('$nome: backspace logo depois de cada separador remove o dígito anterior', () {
        final cheio = _digitar(f, digitos).text;
        for (var i = 0; i < cheio.length; i++) {
          if (RegExp(r'[0-9]').hasMatch(cheio[i])) continue;
          final cursor = i + 1;
          final v = _backspaceEm(f, cheio, cursor);
          final antes = somenteDigitos(cheio.substring(0, cursor));
          if (antes.isEmpty) {
            // Parêntese inicial do telefone: não há dígito antes para apagar.
            expect(v.text, cheio);
            continue;
          }
          final esperado = antes.substring(0, antes.length - 1) + somenteDigitos(cheio.substring(cursor));
          expect(somenteDigitos(v.text), esperado, reason: 'separador "${cheio[i]}" na posição $i');
        }
      });

      test('$nome: digitar no meio mantém o cursor depois do dígito digitado', () {
        final cheio = _digitar(f, digitos.substring(0, digitos.length - 1)).text;
        // Cursor logo depois do 1º dígito.
        final pos = cheio.indexOf(RegExp(r'[0-9]')) + 1;
        final v = _digitarEm(f, cheio, pos, '7');
        expect(somenteDigitos(v.text), '${digitos[0]}7${digitos.substring(1, digitos.length - 1)}');
        expect(somenteDigitos(v.text.substring(0, v.selection.baseOffset)), '${digitos[0]}7');
        expect(v.selection.baseOffset, lessThan(v.text.length));
      });

      test('$nome: backspace no meio não joga o cursor para o fim', () {
        final cheio = _digitar(f, digitos).text;
        // Cursor logo depois do 2º dígito.
        final pos = cheio.indexOf(RegExp(r'[0-9]'), cheio.indexOf(RegExp(r'[0-9]')) + 1) + 1;
        final v = _backspaceEm(f, cheio, pos);
        expect(somenteDigitos(v.text), digitos[0] + digitos.substring(2));
        expect(somenteDigitos(v.text.substring(0, v.selection.baseOffset)), digitos[0]);
      });

      test('$nome: Delete antes de um separador remove o dígito seguinte', () {
        final cheio = _digitar(f, digitos).text;
        final i = cheio.lastIndexOf(RegExp(r'[^0-9]'));
        final v = _deleteEm(f, cheio, i);
        final antes = somenteDigitos(cheio.substring(0, i));
        expect(somenteDigitos(v.text), antes + somenteDigitos(cheio.substring(i)).substring(1));
        expect(somenteDigitos(v.text.substring(0, v.selection.baseOffset)), antes);
      });
    });
  });

  group('helpers', () {
    test('somenteDigitos remove a máscara', () {
      expect(somenteDigitos('(43) 99999-8888'), '43999998888');
      expect(somenteDigitos('111.444.777-35'), '11144477735');
      expect(somenteDigitos(null), '');
    });

    test('formatarTelefone / formatarCpf para exibição', () {
      expect(formatarTelefone('43999998888'), '(43) 99999-8888');
      expect(formatarTelefone('4333334444'), '(43) 3333-4444');
      expect(formatarTelefone(null), '');
      expect(formatarCpf('11144477735'), '111.444.777-35');
    });
  });

  group('TeorAlcoolInputFormatter', () {
    final f = TeorAlcoolInputFormatter();

    for (final valido in ['7', '13', '13,', '13,5', '13.5', '20']) {
      test('aceita "$valido"', () => expect(_digitar(f, valido).text, valido));
    }

    test('bloqueia letras', () => expect(_digitar(f, '1a3b').text, '13'));
    test('bloqueia um terceiro dígito inteiro', () => expect(_digitar(f, '135').text, '13'));
    test('bloqueia uma segunda casa decimal', () => expect(_digitar(f, '13,55').text, '13,5'));
    test('bloqueia um segundo separador', () {
      expect(_digitar(f, '13,,').text, '13,');
      expect(_digitar(f, '13,.').text, '13,');
      expect(_digitar(f, '1,5,').text, '1,5');
    });
    test('bloqueia sinal de menos', () => expect(_digitar(f, '-5').text, '5'));
    test('bloqueia separador sem dígito antes', () => expect(_digitar(f, ',5').text, '5'));
    test('colar texto inválido é ignorado', () {
      expect(_colar(f, '13,55').text, '');
      expect(_colar(f, '12.5').text, '12.5');
    });
    test('backspace funciona normalmente', () => expect(_backspace(f, _digitar(f, '13,5')).text, '13,'));
  });

  group('PrecoInputFormatter', () {
    final f = PrecoInputFormatter();

    for (final valido in ['89', '89,', '89,9', '89,90', '89.90', '1500', '1500,5', '1500000', '0,50']) {
      test('aceita "$valido"', () => expect(_digitar(f, valido).text, valido));
    }

    test('bloqueia letras', () => expect(_digitar(f, '8a9b').text, '89'));
    test('bloqueia sinal de menos', () => expect(_digitar(f, '-89').text, '89'));
    test('bloqueia espaço', () => expect(_digitar(f, '8 9').text, '89'));
    test('bloqueia um segundo separador', () {
      // "1.23" já tem 2 casas: o "4" (3ª casa) e a vírgula (2º separador) são ignorados.
      expect(_digitar(f, '1.234,56').text, '1.23');
      expect(_digitar(f, '89,9,0').text, '89,90');
      expect(_digitar(f, '89,.').text, '89,');
    });
    test('bloqueia uma terceira casa decimal', () => expect(_digitar(f, '89,999').text, '89,99'));
    test('bloqueia separador sem dígito antes', () => expect(_digitar(f, ',5').text, '5'));
    test('colar texto inválido é ignorado', () {
      expect(_colar(f, '1.234,56').text, '');
      expect(_colar(f, 'R\$ 10').text, '');
      expect(_colar(f, '120,00').text, '120,00');
    });
    test('backspace funciona normalmente', () => expect(_backspace(f, _digitar(f, '89,90')).text, '89,9'));
  });
}
