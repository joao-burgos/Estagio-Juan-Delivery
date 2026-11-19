import 'package:flutter_test/flutter_test.dart';

import 'package:front_delivery/core/utils/preco_validator.dart';

void main() {
  group('parsePreco', () {
    test('"89,90" vira 89.90', () => expect(parsePreco('89,90'), 89.90));
    test('"89.9" vira 89.9', () => expect(parsePreco('89.9'), 89.9));
    test('"1500" vira 1500.0', () => expect(parsePreco('1500'), 1500.0));
    test('texto inválido vira null', () => expect(parsePreco('abc'), isNull));
  });

  group('validarPreco', () {
    for (final vazio in ['', '   ', null]) {
      test('recusa vazio ("$vazio")', () => expect(validarPreco(vazio), 'Informe o preço'));
    }
    for (final zero in ['0', '0,0', '0,00', '0.00']) {
      test('recusa "$zero"', () => expect(validarPreco(zero), 'O preço deve ser maior que zero'));
    }
    for (final valido in ['0,50', '0.01', '89', '89,90', '89.90', '1500000']) {
      test('aceita "$valido"', () => expect(validarPreco(valido), isNull));
    }
  });

  group('formatarPreco', () {
    test('120.0 → "120,00"', () => expect(formatarPreco(120.0), '120,00'));
    test('89.9 → "89,90"', () => expect(formatarPreco(89.9), '89,90'));
    test('null → ""', () => expect(formatarPreco(null), ''));
  });
}
