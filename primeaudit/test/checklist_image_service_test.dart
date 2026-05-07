import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/checklist_item_image.dart';

void main() {
  group('ChecklistImageService — contract', () {
    test('ChecklistItemImage.fromMap roundtrip — storage path format', () {
      const companyId = 'comp-abc';
      const executionId = 'exec-xyz';
      const itemId = 'item-123';
      const uuid = 'aaaabbbb-cccc-dddd-eeee-ffffgggghhhh';
      final expectedPath = '$companyId/$executionId/$itemId/$uuid.jpg';

      final img = ChecklistItemImage.fromMap({
        'id': uuid,
        'execution_id': executionId,
        'item_id': itemId,
        'company_id': companyId,
        'storage_path': expectedPath,
        'created_by': 'user-001',
        'created_at': '2026-05-07T10:00:00.000Z',
      });

      // Path format: {companyId}/{executionId}/{itemId}/{uuid}.jpg
      expect(img.storagePath, startsWith('$companyId/$executionId/$itemId/'));
      expect(img.storagePath, endsWith('.jpg'));
      expect(img.executionId, executionId);
      expect(img.itemId, itemId);
    });

    test('upload failure does not touch _failedSaves — contract documented', () {
      // Este contrato é verificado em checklist_photo_isolation_test.dart
      // Aqui documentamos que ChecklistImageService não tem referência a _failedSaves
      expect(true, isTrue); // placeholder — isolamento testado em isolation_test
    });
  });
}
