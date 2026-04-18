// Unit tests for Perimeter.fromMap (QUAL-03) and Perimeter.buildTree (QUAL-04).
// buildTree mutates `children` in place, so each test must construct fresh
// Perimeter instances via _p() — never share instances across tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/perimeter.dart';

Perimeter _p(String id, {String? parentId}) => Perimeter(
  id: id,
  companyId: 'co1',
  parentId: parentId,
  name: 'Perimeter $id',
  active: true,
  createdAt: DateTime(2024, 1, 1),
);

Map<String, dynamic> _mapBase() => <String, dynamic>{
  'id': 'p1',
  'company_id': 'c1',
  'parent_id': null,
  'name': 'Area A',
  'description': null,
  'active': true,
  'created_at': '2024-01-01T00:00:00.000Z',
};

void main() {
  group('Perimeter.fromMap — required fields', () {
    test('parses id, companyId, name, createdAt', () {
      final p = Perimeter.fromMap(_mapBase());
      expect(p.id, equals('p1'));
      expect(p.companyId, equals('c1'));
      expect(p.name, equals('Area A'));
      expect(p.createdAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
    });

    test('parentId and description are null when absent', () {
      final p = Perimeter.fromMap(_mapBase());
      expect(p.parentId, isNull);
      expect(p.description, isNull);
    });

    test('parentId is populated when present', () {
      final m = _mapBase()..['parent_id'] = 'parent1';
      expect(Perimeter.fromMap(m).parentId, equals('parent1'));
    });

    test('description is populated when present', () {
      final m = _mapBase()..['description'] = 'Setor industrial';
      expect(Perimeter.fromMap(m).description, equals('Setor industrial'));
    });
  });

  group('Perimeter.fromMap — active default', () {
    test('active defaults to true when key absent', () {
      final m = _mapBase()..remove('active');
      expect(Perimeter.fromMap(m).active, isTrue);
    });

    test('active is false when explicitly set', () {
      final m = _mapBase()..['active'] = false;
      expect(Perimeter.fromMap(m).active, isFalse);
    });
  });

  group('Perimeter.buildTree — 0 levels', () {
    test('empty list returns empty roots', () {
      expect(Perimeter.buildTree(<Perimeter>[]), isEmpty);
    });
  });

  group('Perimeter.buildTree — 1 level (roots only)', () {
    test('single root has no children', () {
      final roots = Perimeter.buildTree([_p('root')]);
      expect(roots.length, equals(1));
      expect(roots.first.id, equals('root'));
      expect(roots.first.children, isEmpty);
    });

    test('two unrelated roots coexist (both with empty children)', () {
      final roots = Perimeter.buildTree([_p('r1'), _p('r2')]);
      expect(roots.length, equals(2));
      expect(roots[0].id, equals('r1'));
      expect(roots[0].children, isEmpty);
      expect(roots[1].id, equals('r2'));
      expect(roots[1].children, isEmpty);
    });
  });

  group('Perimeter.buildTree — 2 levels (parent + child)', () {
    test('single parent with single child', () {
      final roots = Perimeter.buildTree([
        _p('parent'),
        _p('child', parentId: 'parent'),
      ]);
      expect(roots.length, equals(1));
      expect(roots.first.id, equals('parent'));
      expect(roots.first.children.length, equals(1));
      expect(roots.first.children.first.id, equals('child'));
    });

    test('single parent with multiple children', () {
      final roots = Perimeter.buildTree([
        _p('parent'),
        _p('child_a', parentId: 'parent'),
        _p('child_b', parentId: 'parent'),
        _p('child_c', parentId: 'parent'),
      ]);
      expect(roots.length, equals(1));
      expect(roots.first.children.length, equals(3));
      final childIds = roots.first.children.map((c) => c.id).toList();
      expect(childIds, containsAll(<String>['child_a', 'child_b', 'child_c']));
    });
  });

  group('Perimeter.buildTree — 3 levels (grandparent + parent + grandchild)', () {
    test('nested grandchild inside child inside root', () {
      final roots = Perimeter.buildTree([
        _p('root'),
        _p('child', parentId: 'root'),
        _p('grandchild', parentId: 'child'),
      ]);
      expect(roots.length, equals(1));
      expect(roots.first.children.length, equals(1));
      expect(roots.first.children.first.id, equals('child'));
      expect(roots.first.children.first.children.length, equals(1));
      expect(
        roots.first.children.first.children.first.id,
        equals('grandchild'),
      );
    });

    test('mixed 3-level forest: 2 roots, each with 1 child, one grandchild', () {
      final roots = Perimeter.buildTree([
        _p('r1'),
        _p('r2'),
        _p('c1', parentId: 'r1'),
        _p('c2', parentId: 'r2'),
        _p('g1', parentId: 'c1'),
      ]);
      expect(roots.length, equals(2));
      final r1 = roots.firstWhere((p) => p.id == 'r1');
      final r2 = roots.firstWhere((p) => p.id == 'r2');
      expect(r1.children.length, equals(1));
      expect(r1.children.first.id, equals('c1'));
      expect(r1.children.first.children.length, equals(1));
      expect(r1.children.first.children.first.id, equals('g1'));
      expect(r2.children.length, equals(1));
      expect(r2.children.first.id, equals('c2'));
      expect(r2.children.first.children, isEmpty);
    });
  });

  group('Perimeter.buildTree — orphan handling', () {
    test('child referencing a non-existent parentId is silently dropped', () {
      final orphan = _p('orphan', parentId: 'ghost');
      final root = _p('root');
      final roots = Perimeter.buildTree([root, orphan]);
      expect(roots.length, equals(1));
      expect(roots.first.id, equals('root'));
      expect(roots.first.children, isEmpty);
      // orphan is neither a root (has parentId != null) nor nested anywhere
    });
  });
}
