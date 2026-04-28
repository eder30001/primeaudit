/// Representa uma imagem anexada a um item de auditoria.
///
/// Mapeado da tabela `audit_item_images`. Uma imagem pertence a uma
/// auditoria ([auditId]) e a um item de template ([templateItemId]).
/// O arquivo fica armazenado no bucket Storage `audit-images` no path
/// `{companyId}/{auditId}/{itemId}/{uuid}.jpg`.
class AuditItemImage {
  final String id;
  final String auditId;
  final String templateItemId;
  final String companyId;
  final String storagePath;
  final String createdBy;
  final DateTime createdAt;

  const AuditItemImage({
    required this.id,
    required this.auditId,
    required this.templateItemId,
    required this.companyId,
    required this.storagePath,
    required this.createdBy,
    required this.createdAt,
  });

  factory AuditItemImage.fromMap(Map<String, dynamic> map) {
    return AuditItemImage(
      id: map['id'] as String,
      auditId: map['audit_id'] as String,
      templateItemId: map['template_item_id'] as String,
      companyId: map['company_id'] as String,
      storagePath: map['storage_path'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
