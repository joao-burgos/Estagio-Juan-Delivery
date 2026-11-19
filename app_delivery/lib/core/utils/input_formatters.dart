import 'package:flutter/services.dart';

/// Remove tudo que não for dígito (o backend espera só números).
String somenteDigitos(String? valor) => (valor ?? '').replaceAll(RegExp(r'[^0-9]'), '');

/// Formata um telefone no padrão (XX) XXXX-XXXX (fixo, 10 dígitos) ou
/// (XX) XXXXX-XXXX (celular, 11 dígitos). Aceita valores parciais.
String formatarTelefone(String? valor) {
  var d = somenteDigitos(valor);
  if (d.length > 11) d = d.substring(0, 11);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';

  final ddd = d.substring(0, 2);
  final numero = d.substring(2);
  if (numero.length <= 5) return '($ddd) $numero';

  // Celular (9 dígitos no número): hífen após o 5º; senão após o 4º.
  final corte = numero.length == 9 ? 5 : 4;
  return '($ddd) ${numero.substring(0, corte)}-${numero.substring(corte)}';
}

/// Formata um CPF no padrão XXX.XXX.XXX-XX. Aceita valores parciais.
String formatarCpf(String? valor) {
  var d = somenteDigitos(valor);
  if (d.length > 11) d = d.substring(0, 11);

  final buffer = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 3 || i == 6) buffer.write('.');
    if (i == 9) buffer.write('-');
    buffer.write(d[i]);
  }
  return buffer.toString();
}

/// Formata um CEP no padrão XXXXX-XXX. Aceita valores parciais.
String formatarCep(String? valor) {
  var d = somenteDigitos(valor);
  if (d.length > 8) d = d.substring(0, 8);
  return d.length <= 5 ? d : '${d.substring(0, 5)}-${d.substring(5)}';
}

/// Base dos formatters de máscara: extrai só os dígitos do texto novo, limita a
/// quantidade e remonta a máscara a partir deles. O cursor é reposicionado pela
/// quantidade de dígitos que havia antes dele, então editar no meio do campo não
/// joga o cursor para o fim.
///
/// Se a edição apagar apenas um símbolo da máscara (parêntese, ponto, espaço ou
/// hífen), o dígito vizinho também é removido — o anterior no backspace, o
/// seguinte no delete —, para que apagar não "trave" diante do símbolo.
abstract class _MascaraNumericaFormatter extends TextInputFormatter {
  int get maxDigitos;
  String formatar(String digitos);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digitos = somenteDigitos(newValue.text);
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    var digitosAntes = somenteDigitos(newValue.text.substring(0, cursor)).length;

    final apagouSoSimbolo = newValue.text.length < oldValue.text.length && digitos == somenteDigitos(oldValue.text);
    if (apagouSoSimbolo) {
      final deleteParaFrente =
          oldValue.selection.isValid && oldValue.selection.isCollapsed && oldValue.selection.baseOffset == cursor;
      if (deleteParaFrente) {
        if (digitosAntes < digitos.length) {
          digitos = digitos.substring(0, digitosAntes) + digitos.substring(digitosAntes + 1);
        }
      } else if (digitosAntes > 0) {
        digitos = digitos.substring(0, digitosAntes - 1) + digitos.substring(digitosAntes);
        digitosAntes--;
      }
    }

    if (digitos.length > maxDigitos) digitos = digitos.substring(0, maxDigitos);
    if (digitosAntes > digitos.length) digitosAntes = digitos.length;

    final texto = formatar(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: _posicaoAposDigitos(texto, digitosAntes, digitos.length)),
    );
  }

  /// Posição logo depois do [n]-ésimo dígito de [texto]; com todos os dígitos
  /// antes do cursor, vai para o fim (depois de um eventual símbolo final).
  static int _posicaoAposDigitos(String texto, int n, int total) {
    if (n <= 0) return 0;
    if (n >= total) return texto.length;
    var vistos = 0;
    for (var i = 0; i < texto.length; i++) {
      if (_ehDigito(texto.codeUnitAt(i)) && ++vistos == n) return i + 1;
    }
    return texto.length;
  }

  static bool _ehDigito(int c) => c >= 0x30 && c <= 0x39;
}

/// Máscara dinâmica de telefone: (XX) XXXX-XXXX ou (XX) XXXXX-XXXX.
class TelefoneInputFormatter extends _MascaraNumericaFormatter {
  @override
  int get maxDigitos => 11;

  @override
  String formatar(String digitos) => formatarTelefone(digitos);
}

/// Máscara de CPF: XXX.XXX.XXX-XX.
class CpfInputFormatter extends _MascaraNumericaFormatter {
  @override
  int get maxDigitos => 11;

  @override
  String formatar(String digitos) => formatarCpf(digitos);
}

/// Máscara de CEP: XXXXX-XXX.
class CepInputFormatter extends _MascaraNumericaFormatter {
  @override
  int get maxDigitos => 8;

  @override
  String formatar(String digitos) => formatarCep(digitos);
}

/// Teor alcoólico: até 2 dígitos inteiros e, opcionalmente, 1 casa decimal
/// separada por vírgula ou ponto (ex.: "7", "13,", "13,5", "20"). Qualquer
/// edição fora desse formato (letras, sinal, "135", "13,55", "13,5,") é ignorada.
class TeorAlcoolInputFormatter extends TextInputFormatter {
  static final _formato = RegExp(r'^(\d{1,2}([.,]\d?)?)?$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _formato.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Preço: dígitos sem limite na parte inteira e, opcionalmente, até 2 casas
/// decimais separadas por vírgula ou ponto (ex.: "89", "89,", "89,9", "89.90").
/// Qualquer edição fora desse formato (letras, sinal, espaço, segundo separador,
/// terceira casa decimal) é ignorada.
class PrecoInputFormatter extends TextInputFormatter {
  static final _formato = RegExp(r'^(\d+([.,]\d{0,2})?)?$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _formato.hasMatch(newValue.text) ? newValue : oldValue;
}
