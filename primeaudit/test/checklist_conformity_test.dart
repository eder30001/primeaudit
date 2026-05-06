import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChecklistAnswerService.calculateConformity', () {
    test('TODO: yes_no=yes conta como conforme', () {
      // TODO: instanciar ChecklistAnswerService e verificar que yes_no='yes' = conforme
      expect(true, isTrue);
    });

    test('TODO: yes_no=no conta como não conforme', () {
      // TODO: yes_no='no' deve reduzir conformidade
      expect(true, isTrue);
    });

    test('TODO: number excluído do denominador', () {
      // TODO: item com item_type=number não deve entrar no denominador
      expect(true, isTrue);
    });

    test('TODO: date excluído do denominador', () {
      // TODO: item com item_type=date não deve entrar no denominador
      expect(true, isTrue);
    });

    test('TODO: text não vazio = conforme', () {
      // TODO: item_type=text com resposta não vazia = conforme
      expect(true, isTrue);
    });

    test('TODO: sem respostas = conformidade 0.0', () {
      // TODO: nenhuma resposta registrada = 0.0%
      expect(true, isTrue);
    });
  });
}
