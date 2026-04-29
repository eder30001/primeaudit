import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_item_image.dart';

/// Gerencia imagens de itens de auditoria (tabela `audit_item_images` + bucket Storage `audit-images`).
///
/// Fluxo de upload: bytes via [XFile.readAsBytes] → Storage.uploadBinary →
/// INSERT em audit_item_images → retorna [AuditItemImage] com path e metadados.
///
/// Nota: [uploadImage] lança exceção em caso de falha — o caller (_ImageStrip)
/// é responsável por gerenciar o estado de erro sem bloquear _saveAnswer.
class ImageService {
  final _client = Supabase.instance.client;
  static const _bucket = 'audit-images';

  /// Gera UUID v4 sem dependência externa (dart:math com Random.secure).
  String _uuid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return [
      bytes.sublist(0, 4),
      bytes.sublist(4, 6),
      bytes.sublist(6, 8),
      bytes.sublist(8, 10),
      bytes.sublist(10, 16),
    ].map((b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()).join('-');
  }

  /// Faz upload de uma imagem para o Storage e registra metadados na tabela.
  ///
  /// Path no Storage: `{companyId}/{auditId}/{itemId}/{uuid}.jpg`
  ///
  /// Lança exceção em caso de falha de upload ou erro de DB.
  /// O caller (_ImageStrip) gerencia o estado de erro sem propagar para _saveAnswer.
  Future<AuditItemImage> uploadImage({
    required String companyId,
    required String auditId,
    required String itemId,
    required XFile file,
  }) async {
    final uuid = _uuid();
    final path = '$companyId/$auditId/$itemId/$uuid.jpg';
    final bytes = await file.readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
    );

    final userId = _client.auth.currentUser!.id;
    final row = await _client.from('audit_item_images').insert({
      'audit_id': auditId,
      'template_item_id': itemId,
      'company_id': companyId,
      'storage_path': path,
      'created_by': userId,
    }).select().single();

    return AuditItemImage.fromMap(row);
  }

  /// Retorna lista de imagens de um item, ordenadas por created_at ASC.
  /// Se [correctiveActionId] for informado, filtra apenas as imagens dessa ação.
  Future<List<AuditItemImage>> getImages({
    required String auditId,
    required String itemId,
    String? correctiveActionId,
  }) async {
    var q = _client
        .from('audit_item_images')
        .select()
        .eq('audit_id', auditId)
        .eq('template_item_id', itemId);
    if (correctiveActionId != null) {
      q = q.eq('corrective_action_id', correctiveActionId);
    }
    final rows = await q.order('created_at');
    return (rows as List).map((r) => AuditItemImage.fromMap(r)).toList();
  }

  /// Vincula imagens já salvas a uma ação corretiva específica.
  Future<void> linkImagesToAction(List<String> imageIds, String actionId) async {
    if (imageIds.isEmpty) return;
    await _client
        .from('audit_item_images')
        .update({'corrective_action_id': actionId})
        .inFilter('id', imageIds);
  }

  /// Gera signed URL com validade de 1 hora para exibição de imagem privada.
  Future<String> getSignedUrl(String storagePath) async {
    return await _client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Remove imagem do Storage (best-effort) e exclui o registro da tabela.
  ///
  /// O Storage remove é best-effort: falha silenciosa se o objeto já não existir.
  /// O delete da tabela propaga erro para o caller gerenciar estado de retry.
  Future<void> deleteImage({
    required String imageId,
    required String storagePath,
  }) async {
    // Remove do Storage primeiro (best-effort — não lança se já não existir)
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
    } catch (_) {
      // Storage delete falhou — continua para remover o registro da tabela
    }
    await _client.from('audit_item_images').delete().eq('id', imageId);
  }
}
