// Unit tests for TemplateItem.fromMap and AuditTemplate.fromMap (QUAL-03).

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit_template.dart';

Map<String, dynamic> _itemMap() => <String, dynamic>{
  'id': 'ti1',
  'template_id': 't1',
  'section_id': null,
  'question': 'Item conforme?',
  'guidance': null,
  'response_type': 'ok_nok',
  'required': true,
  'weight': 3,
  'order_index': 0,
  'options': <dynamic>[],
};

Map<String, dynamic> _templateMap() => <String, dynamic>{
  'id': 't1',
  'type_id': 'at1',
  'company_id': null,
  'name': 'Template A',
  'description': null,
  'active': true,
  'audit_types': {'name': 'Safety', 'icon': '📋'},
};

void main() {
  group('TemplateItem.fromMap — required fields', () {
    test('parses id, templateId, question, responseType, weight', () {
      final item = TemplateItem.fromMap(_itemMap());
      expect(item.id, equals('ti1'));
      expect(item.templateId, equals('t1'));
      expect(item.question, equals('Item conforme?'));
      expect(item.responseType, equals('ok_nok'));
      expect(item.weight, equals(3));
      expect(item.orderIndex, equals(0));
      expect(item.required, isTrue);
    });

    test('sectionId and guidance are null when absent', () {
      final item = TemplateItem.fromMap(_itemMap());
      expect(item.sectionId, isNull);
      expect(item.guidance, isNull);
    });
  });

  group('TemplateItem.fromMap — defaults', () {
    test('response_type defaults to ok_nok when key absent', () {
      final m = _itemMap()..remove('response_type');
      expect(TemplateItem.fromMap(m).responseType, equals('ok_nok'));
    });

    test('required defaults to true when key absent', () {
      final m = _itemMap()..remove('required');
      expect(TemplateItem.fromMap(m).required, isTrue);
    });

    test('weight defaults to 1 when key absent', () {
      final m = _itemMap()..remove('weight');
      expect(TemplateItem.fromMap(m).weight, equals(1));
    });

    test('order_index defaults to 0 when key absent', () {
      final m = _itemMap()..remove('order_index');
      expect(TemplateItem.fromMap(m).orderIndex, equals(0));
    });

    test('options defaults to [] when key absent', () {
      final m = _itemMap()..remove('options');
      expect(TemplateItem.fromMap(m).options, isEmpty);
    });
  });

  group('TemplateItem.fromMap — options list', () {
    test('casts List<dynamic> of strings to List<String>', () {
      final m = _itemMap()..['options'] = <dynamic>['a', 'b', 'c'];
      final item = TemplateItem.fromMap(m);
      expect(item.options, equals(<String>['a', 'b', 'c']));
    });
  });

  group('AuditTemplate.fromMap — required fields', () {
    test('parses id, typeId, name, active', () {
      final t = AuditTemplate.fromMap(_templateMap());
      expect(t.id, equals('t1'));
      expect(t.typeId, equals('at1'));
      expect(t.name, equals('Template A'));
      expect(t.active, isTrue);
    });

    test('description is null when absent', () {
      expect(AuditTemplate.fromMap(_templateMap()).description, isNull);
    });

    test('active defaults to true when key absent', () {
      final m = _templateMap()..remove('active');
      expect(AuditTemplate.fromMap(m).active, isTrue);
    });
  });

  group('AuditTemplate.fromMap — audit_types join', () {
    test('populates typeName and typeIcon from nested audit_types map', () {
      final t = AuditTemplate.fromMap(_templateMap());
      expect(t.typeName, equals('Safety'));
      expect(t.typeIcon, equals('📋'));
    });

    test('typeName and typeIcon are null when audit_types is null', () {
      final m = _templateMap()..['audit_types'] = null;
      final t = AuditTemplate.fromMap(m);
      expect(t.typeName, isNull);
      expect(t.typeIcon, isNull);
    });
  });

  group('AuditTemplate.isGlobal', () {
    test('isGlobal is true when company_id is null', () {
      expect(AuditTemplate.fromMap(_templateMap()).isGlobal, isTrue);
    });

    test('isGlobal is false when company_id is set', () {
      final m = _templateMap()..['company_id'] = 'c1';
      expect(AuditTemplate.fromMap(m).isGlobal, isFalse);
    });
  });
}
