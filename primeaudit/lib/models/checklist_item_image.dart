/// Representa uma imagem anexada a um item de checklist.
///
/// Mapeado da tabela `checklist_item_images`. Uma imagem pertence a uma
/// execução de checklist ([executionId]) e a um item de template ([itemId]).
/// O arquivo fica armazenado no bucket Storage `checklist-images` no path
/// `{companyId}/{executionId}/{itemId}/{uuid}.jpg`.
///
/// Módulo Checklist independente — sem referência a AuditItemImage ou ImageService.
class ChecklistItemImage {
  final String id;
  final String executionId;
  final String itemId;
  final String companyId;
  final String storagePath;
  final String createdBy;
  final DateTime createdAt;

  const ChecklistItemImage({
    required this.id,
    required this.executionId,
    required this.itemId,
    required this.companyId,
    required this.storagePath,
    required this.createdBy,
    required this.createdAt,
  });

  factory ChecklistItemImage.fromMap(Map<String, dynamic> map) {
    return ChecklistItemImage(
      id: map['id'] as String,
      executionId: map['execution_id'] as String,
      itemId: map['item_id'] as String,
      companyId: map['company_id'] as String,
      storagePath: map['storage_path'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
