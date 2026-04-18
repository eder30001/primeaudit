/// Validação de CNPJ (Cadastro Nacional da Pessoa Jurídica).
///
/// Implementa o algoritmo oficial da Receita Federal (dígitos verificadores),
/// não apenas verificação de comprimento. Puro Dart — sem dependências Flutter
/// ou Supabase. Pode ser usado tanto pelo app (TextFormField.validator) quanto
/// por testes unitários.
///
/// Exposto como duas funções top-level (sem wrapper de classe — D-02: função pura):
///   - `isValidCnpj(String)` — true/false, decisão pura
///   - `validateCnpj(String?)` — wrapper compatível com TextFormField.validator
library;

/// Retorna true se [cnpj] passa na validação de dígitos verificadores.
///
/// Aceita entrada formatada (com pontos, barras, hífens, espaços) ou crua
/// (14 dígitos contínuos). Rejeita:
///   - comprimento diferente de 14 dígitos (após limpeza)
///   - caracteres não-dígito em posições de dígito
///   - CNPJs com todos os 14 dígitos iguais (ex: 00000000000000)
///   - CNPJs onde os dois dígitos verificadores (posições 12 e 13) não conferem
bool isValidCnpj(String cnpj) {
  final digits = cnpj.replaceAll(RegExp(r'[.\-/\s]'), '');
  if (digits.length != 14) return false;
  // Aceita apenas dígitos em todas as 14 posições
  if (!RegExp(r'^\d{14}$').hasMatch(digits)) return false;
  // Rejeita sequências de um único dígito repetido (11111111111111 etc.)
  if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;

  int calc(String s, List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += int.parse(s[i]) * weights[i];
    }
    final rem = sum % 11;
    return rem < 2 ? 0 : 11 - rem;
  }

  const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  final d1 = calc(digits, w1);
  final d2 = calc(digits, w2);

  return d1 == int.parse(digits[12]) && d2 == int.parse(digits[13]);
}

/// Validator compatível com `TextFormField.validator:`.
///
/// Retorna:
///   - null para entrada vazia/nula (campo opcional — D-03 / Pitfall 4)
///   - "CNPJ deve ter 14 dígitos" para entrada não-vazia com comprimento incorreto
///   - "CNPJ inválido — dígitos verificadores incorretos" para 14 dígitos com checksum inválido
///   - null para CNPJ válido
String? validateCnpj(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final digits = value.replaceAll(RegExp(r'[.\-/\s]'), '');
  if (digits.length != 14) return 'CNPJ deve ter 14 dígitos';
  if (!isValidCnpj(value)) return 'CNPJ inválido — dígitos verificadores incorretos';
  return null;
}
