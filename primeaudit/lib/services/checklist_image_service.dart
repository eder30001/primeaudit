import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_item_image.dart';

/// Gerencia imagens de itens de checklist (tabela `checklist_item_images` + bucket `checklist-images`).
///
/// Módulo independente — não altera nem depende de [ImageService] ou [AuditItemImage].
///
/// Fluxo de upload: bytes via [XFile.readAsBytes] → Storage.uploadBinary →
/// INSERT em checklist_item_images → retorna [ChecklistItemImage] com path e metadados.
///
/// Nota: [uploadImage] lança exceção em caso de falha — o caller (_ChecklistPhotoStrip)
/// é responsável por gerenciar o estado de erro sem bloquear _finalize.
class ChecklistImageService {
  final _client = Supabase.instance.client;
  static const _bucket = 'checklist-images';

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
  /// Path no Storage: `{companyId}/{executionId}/{itemId}/{uuid}.jpg`
  ///
  /// Lança exceção em caso de falha de upload ou erro de DB.
  /// O caller (_ChecklistPhotoStrip) gerencia o estado de erro sem propagar para _finalize.
  Future<ChecklistItemImage> uploadImage({
    required String companyId,
    required String executionId,
    required String itemId,
    required XFile file,
  }) async {
    final uuid = _uuid();
    final path = '$companyId/$executionId/$itemId/$uuid.jpg';
    final bytes = await file.readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
    );

    final userId = _client.auth.currentUser!.id;
    final row = await _client.from('checklist_item_images').insert({
      'execution_id': executionId,
      'item_id': itemId,
      'company_id': companyId,
      'storage_path': path,
      'created_by': userId,
    }).select().single();

    return ChecklistItemImage.fromMap(row);
  }

  /// Retorna lista de imagens de um item específico, ordenadas por created_at ASC.
  Future<List<ChecklistItemImage>> getImages({
    required String executionId,
    required String itemId,
  }) async {
    final rows = await _client
        .from('checklist_item_images')
        .select()
        .eq('execution_id', executionId)
        .eq('item_id', itemId)
        .order('created_at');
    return (rows as List).map((r) => ChecklistItemImage.fromMap(r)).toList();
  }

  /// Carrega TODAS as imagens da execução em uma única query — usado em _load().
  ///
  /// Evita N+1: busca todas as imagens de uma vez e o caller distribui por item_id.
  Future<List<ChecklistItemImage>> getImagesByExecution(String executionId) async {
    final rows = await _client
        .from('checklist_item_images')
        .select()
        .eq('execution_id', executionId)
        .order('created_at');
    return (rows as List).map((r) => ChecklistItemImage.fromMap(r)).toList();
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
    await _client.from('checklist_item_images').delete().eq('id', imageId);
  }
}
