// Unit tests para PendingSave (lib/screens/pending_save.dart).
// Cobre o comportamento imutável e o helper copyWithAttempt usado no
// retry com backoff exponencial da tela de execução de auditoria.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/screens/pending_save.dart';

void main() {
  group('PendingSave', () {
    test('copyWithAttempt incrementa attemptCount preservando outros campos', () {
      const pending = PendingSave(
        itemId: 'item-1',
        response: 'ok',
        observation: 'obs teste',
        attemptCount: 2,
      );

      final next = pending.copyWithAttempt();

      expect(next.attemptCount, equals(3));
      expect(next.itemId, equals('item-1'));
      expect(next.response, equals('ok'));
      expect(next.observation, equals('obs teste'));
    });

    test('attemptCount default é 0 quando não informado', () {
      const pending = PendingSave(itemId: 'x', response: 'yes');
      expect(pending.attemptCount, equals(0));
    });

    test('observation default é null quando não informado', () {
      const pending = PendingSave(itemId: 'x', response: 'yes');
      expect(pending.observation, isNull);
    });

    test('copyWithAttempt preserva observation null', () {
      const pending = PendingSave(itemId: 'x', response: 'y');

      final next = pending.copyWithAttempt();

      expect(next.observation, isNull);
      expect(next.attemptCount, equals(1));
    });

    test('copyWithAttempt é cumulativo — 3 chamadas incrementam para 3', () {
      const pending = PendingSave(itemId: 'a', response: 'b');
      final after3 = pending.copyWithAttempt().copyWithAttempt().copyWithAttempt();
      expect(after3.attemptCount, equals(3));
    });
  });
}
