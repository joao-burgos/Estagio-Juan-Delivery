/// Converte o texto do campo de preço em número, aceitando vírgula (89,90) ou
/// ponto (89.90). Retorna null se não for um número.
double? parsePreco(String? valor) => double.tryParse((valor ?? '').trim().replaceAll(',', '.'));

/// Valida o campo de preço: obrigatório e maior que zero.
String? validarPreco(String? valor) {
  if ((valor ?? '').trim().isEmpty) return 'Informe o preço';
  final preco = parsePreco(valor);
  if (preco == null) return 'Valor inválido';
  if (preco <= 0) return 'O preço deve ser maior que zero';
  return null;
}

/// Texto do campo para um preço vindo da API: 120.0 → "120,00"; 89.9 → "89,90".
String formatarPreco(double? preco) => preco == null ? '' : preco.toStringAsFixed(2).replaceAll('.', ',');
