// Unit tests for ChecklistTemplate.fromMap and ChecklistTemplateItem.fromMap.
// Covers TMPLCK-01, TMPLCK-02, TMPLCK-03, TMPLCK-04.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/checklist_template.dart';

Map<String, dynamic> _templateMap() => <String, dynamic>{
  'id': 'tmpl-1',
  'name': 'Template Teste',
  'category': 'industrial',
  'description': 'Desc',
  'is_padrao': true,
  'company_id': null,
  'created_by': null,
  'created_at': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> _itemMap() => <String, dynamic>{
  'id': 'item-1',
  'template_id': 'tmpl-1',
  'description': 'Pergunta 1',
  'item_type': 'yes_no',
  'order_index': 0,
};

void main() {
  group('ChecklistTemplate.fromMap — required fields (TMPLCK-01)', () {
    test('parses id, name, category, isPadrao', () {
      final t = ChecklistTemplate.fromMap(_templateMap());
      expect(t.id, equals('tmpl-1'));
      expect(t.name, equals('Template Teste'));
      expect(t.category, equals('industrial'));
      expect(t.isPadrao, isTrue);
    });

    test('parses optional description', () {
      final t = ChecklistTemplate.fromMap(_templateMap());
      expect(t.description, equals('Desc'));
    });

    test('parses createdAt as DateTime', () {
      final t = ChecklistTemplate.fromMap(_templateMap());
      expect(t.createdAt, isA<DateTime>());
    });
  });

  group('ChecklistTemplate.fromMap — defaults (TMPLCK-04)', () {
    test('category defaults to industrial when key absent', () {
      final m = _templateMap()..remove('category');
      expect(ChecklistTemplate.fromMap(m).category, equals('industrial'));
    });

    test('isPadrao defaults to false when key absent', () {
      final m = _templateMap()..remove('is_padrao');
      expect(ChecklistTemplate.fromMap(m).isPadrao, isFalse);
    });

    test('description is null when key absent', () {
      final m = _templateMap()..remove('description');
      expect(ChecklistTemplate.fromMap(m).description, isNull);
    });
  });

  group('ChecklistTemplate.isSeed getter (TMPLCK-03)', () {
    test('isSeed returns true when isPadrao is true', () {
      final t = ChecklistTemplate.fromMap(_templateMap());
      expect(t.isSeed, isTrue);
    });

    test('isSeed returns false when isPadrao is false', () {
      final m = _templateMap()..['is_padrao'] = false;
      expect(ChecklistTemplate.fromMap(m).isSeed, isFalse);
    });
  });

  group('ChecklistTemplateItem.fromMap — required fields (TMPLCK-02)', () {
    test('parses id, templateId, description, itemType, orderIndex', () {
      final item = ChecklistTemplateItem.fromMap(_itemMap());
      expect(item.id, equals('item-1'));
      expect(item.templateId, equals('tmpl-1'));
      expect(item.description, equals('Pergunta 1'));
      expect(item.itemType, equals('yes_no'));
      expect(item.orderIndex, equals(0));
    });
  });

  group('ChecklistTemplateItem.fromMap — defaults (TMPLCK-02)', () {
    test('itemType defaults to yes_no when key absent', () {
      final m = _itemMap()..remove('item_type');
      expect(ChecklistTemplateItem.fromMap(m).itemType, equals('yes_no'));
    });

    test('orderIndex defaults to 0 when key absent', () {
      final m = _itemMap()..remove('order_index');
      expect(ChecklistTemplateItem.fromMap(m).orderIndex, equals(0));
    });

    test('description defaults to empty string when key absent', () {
      final m = _itemMap()..remove('description');
      expect(ChecklistTemplateItem.fromMap(m).description, equals(''));
    });
  });
}
