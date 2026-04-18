// Unit tests for AuditAnswer.fromMap (QUAL-03).
// AuditAnswer is the flattest of the models — no nested joins.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit_answer.dart';

Map<String, dynamic> _baseMap() => <String, dynamic>{
  'id': 'aa1',
  'audit_id': 'a1',
  'template_item_id': 'ti1',
  'response': 'ok',
  'observation': null,
  'answered_at': '2024-01-01T10:00:00.000Z',
};

void main() {
  group('AuditAnswer.fromMap', () {
    test('parses required scalar fields', () {
      final aa = AuditAnswer.fromMap(_baseMap());
      expect(aa.id, equals('aa1'));
      expect(aa.auditId, equals('a1'));
      expect(aa.templateItemId, equals('ti1'));
      expect(aa.response, equals('ok'));
    });

    test('parses answeredAt as DateTime', () {
      final aa = AuditAnswer.fromMap(_baseMap());
      expect(
        aa.answeredAt,
        equals(DateTime.parse('2024-01-01T10:00:00.000Z')),
      );
    });

    test('observation is null when map value is null', () {
      final aa = AuditAnswer.fromMap(_baseMap());
      expect(aa.observation, isNull);
    });

    test('observation is populated when present', () {
      final m = _baseMap()..['observation'] = 'Observação do auditor';
      expect(AuditAnswer.fromMap(m).observation, equals('Observação do auditor'));
    });

    test('response may be any string (numeric payload for scale_1_5)', () {
      final m = _baseMap()..['response'] = '5';
      expect(AuditAnswer.fromMap(m).response, equals('5'));
    });
  });
}
