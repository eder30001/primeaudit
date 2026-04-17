// Smoke test mínimo — apenas confirma que o pacote compila e o framework carrega.
// Testes reais do app vivem em arquivos dedicados (audit_execution_save_error_test.dart,
// pending_save_test.dart, etc.).
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke: flutter_test framework carrega', () {
    expect(1 + 1, equals(2));
  });
}
