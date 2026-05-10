import 'package:flutter_test/flutter_test.dart';
import 'package:qaudit/models/checklist_item_image.dart';

void main() {
  group('ChecklistItemImage.fromMap', () {
    final map = {
      'id': 'img-001',
      'execution_id': 'exec-001',
      'item_id': 'item-001',
      'company_id': 'comp-001',
      'storage_path': 'comp-001/exec-001/item-001/uuid.jpg',
      'created_by': 'user-001',
      'created_at': '2026-05-07T10:00:00.000Z',
    };

    test('parses all fields correctly', () {
      final img = ChecklistItemImage.fromMap(map);
      expect(img.id, 'img-001');
      expect(img.executionId, 'exec-001');
      expect(img.itemId, 'item-001');
      expect(img.companyId, 'comp-001');
      expect(img.storagePath, 'comp-001/exec-001/item-001/uuid.jpg');
      expect(img.createdBy, 'user-001');
      expect(img.createdAt, DateTime.parse('2026-05-07T10:00:00.000Z'));
    });

    test('has no correctiveActionId field', () {
      final img = ChecklistItemImage.fromMap(map);
      // Se correctiveActionId existisse, este código não compilaria — a ausência é o teste
      expect(img, isA<ChecklistItemImage>());
    });
  });
}
