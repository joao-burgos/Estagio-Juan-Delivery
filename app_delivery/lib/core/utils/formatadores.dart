/// Formata um valor em reais no padrão brasileiro: 1234.5 → "R$ 1.234,50".
String formatarReais(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return 'R\$ $inteiro,${partes[1]}';
}

/// Data no formato "dd/MM/aaaa".
String formatarDia(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
