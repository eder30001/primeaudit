import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_type.dart';
import '../models/audit_template.dart';

/// Gerencia tipos de auditoria, templates, seções e itens no Supabase.
///
/// Estrutura de dados:
///   [AuditType] → [AuditTemplate] → [TemplateSection] → [TemplateItem]
///
/// Templates e tipos com [companyId] == null são globais; quando [companyId]
/// é fornecido, o filtro usa OR para incluir globais + os da empresa.
///
/// Métodos com sufixo `Cached` persistem o resultado em SharedPreferences e
/// retornam o cache quando a chamada de rede falha (suporte offline).
class AuditTemplateService {
  final _client = Supabase.instance.client;

  // ── Chaves de cache ────────────────────────────────
  static String _typesKey(String? companyId) =>
      'cache_audit_types_${companyId ?? 'global'}';

  static String _templatesKey(String typeId, String? companyId) =>
      'cache_audit_templates_${typeId}_${companyId ?? 'global'}';

  // ── Tipos ──────────────────────────────────────────
  Future<List<AuditType>> getTypes({String? companyId}) async {
    var query = _client.from('audit_types').select();
    if (companyId != null) {
      query = query.or('company_id.is.null,company_id.eq.$companyId');
    } else {
      query = query.filter('company_id', 'is', null);
    }
    final data = await query.eq('active', true).order('name');
    return (data as List).map((e) => AuditType.fromMap(e)).toList();
  }

  /// Igual a [getTypes] mas persiste o resultado em cache e usa o cache
  /// quando a chamada de rede falha (suporte a modo offline).
  Future<List<AuditType>> getTypesCached({String? companyId}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _typesKey(companyId);
    try {
      final types = await getTypes(companyId: companyId);
      // Grava cache após fetch bem-sucedido
      final encoded = jsonEncode(types.map((t) => _auditTypeToMap(t)).toList());
      await prefs.setString(cacheKey, encoded);
      return types;
    } catch (_) {
      // Rede indisponível — tenta ler o cache
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        return list.map((e) => AuditType.fromMap(e as Map<String, dynamic>)).toList();
      }
      rethrow; // sem cache disponível — propaga o erro
    }
  }

  Future<AuditType> createType({
    required String name,
    required String icon,
    required String color,
    String? companyId,
  }) async {
    final result = await _client
        .from('audit_types')
        .insert({'name': name, 'icon': icon, 'color': color, 'company_id': companyId})
        .select()
        .single();
    return AuditType.fromMap(result);
  }

  Future<void> updateType(String id, String name, String icon, String color) async {
    await _client
        .from('audit_types')
        .update({'name': name, 'icon': icon, 'color': color})
        .eq('id', id);
  }

  Future<void> deleteType(String id) async {
    await _client.from('audit_types').delete().eq('id', id);
  }

  // ── Templates ──────────────────────────────────────
  Future<List<AuditTemplate>> getTemplates({
    required String typeId,
    String? companyId,
  }) async {
    var query = _client
        .from('audit_templates')
        .select('*, audit_types(name, icon)')
        .eq('type_id', typeId);

    if (companyId != null) {
      query = query.or('company_id.is.null,company_id.eq.$companyId');
    } else {
      query = query.filter('company_id', 'is', null);
    }

    final data = await query.order('name');
    return (data as List).map((e) => AuditTemplate.fromMap(e)).toList();
  }

  /// Igual a [getTemplates] mas persiste o resultado em cache e usa o cache
  /// quando a chamada de rede falha (suporte a modo offline).
  Future<List<AuditTemplate>> getTemplatesCached({
    required String typeId,
    String? companyId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _templatesKey(typeId, companyId);
    try {
      final templates = await getTemplates(typeId: typeId, companyId: companyId);
      // Grava cache após fetch bem-sucedido
      final encoded = jsonEncode(
        templates.map((t) => _auditTemplateToMap(t)).toList(),
      );
      await prefs.setString(cacheKey, encoded);
      return templates;
    } catch (_) {
      // Rede indisponível — tenta ler o cache
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        return list
            .map((e) => AuditTemplate.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      rethrow; // sem cache disponível — propaga o erro
    }
  }

  Future<List<AuditTemplate>> getAllTemplates({String? companyId}) async {
    var query = _client
        .from('audit_templates')
        .select('*, audit_types(name, icon)');

    if (companyId != null) {
      query = query.or('company_id.is.null,company_id.eq.$companyId');
    }

    final data = await query.order('name');
    return (data as List).map((e) => AuditTemplate.fromMap(e)).toList();
  }

  Future<AuditTemplate> createTemplate({
    required String typeId,
    required String name,
    String? description,
    String? companyId,
  }) async {
    final result = await _client
        .from('audit_templates')
        .insert({
          'type_id': typeId,
          'name': name,
          'description': description,
          'company_id': companyId,
        })
        .select('*, audit_types(name, icon)')
        .single();
    return AuditTemplate.fromMap(result);
  }

  Future<void> updateTemplate(String id, String name, String? description) async {
    await _client
        .from('audit_templates')
        .update({'name': name, 'description': description})
        .eq('id', id);
  }

  Future<void> toggleTemplate(String id, bool active) async {
    await _client.from('audit_templates').update({'active': active}).eq('id', id);
  }

  Future<void> deleteTemplate(String id) async {
    await _client.from('audit_templates').delete().eq('id', id);
  }

  // ── Seções ─────────────────────────────────────────
  Future<List<TemplateSection>> getSections(String templateId) async {
    final data = await _client
        .from('template_sections')
        .select()
        .eq('template_id', templateId)
        .order('order_index');
    return (data as List).map((e) => TemplateSection.fromMap(e)).toList();
  }

  Future<TemplateSection> createSection(String templateId, String name, int order) async {
    final result = await _client
        .from('template_sections')
        .insert({'template_id': templateId, 'name': name, 'order_index': order})
        .select()
        .single();
    return TemplateSection.fromMap(result);
  }

  Future<void> updateSection(String id, String name) async {
    await _client.from('template_sections').update({'name': name}).eq('id', id);
  }

  Future<void> deleteSection(String id) async {
    await _client.from('template_sections').delete().eq('id', id);
  }

  // ── Itens ──────────────────────────────────────────
  Future<List<TemplateItem>> getItems(String templateId) async {
    final data = await _client
        .from('template_items')
        .select()
        .eq('template_id', templateId)
        .order('order_index');
    return (data as List).map((e) => TemplateItem.fromMap(e)).toList();
  }

  Future<TemplateItem> createItem({
    required String templateId,
    String? sectionId,
    required String question,
    String? guidance,
    required String responseType,
    required bool required,
    required int weight,
    required int orderIndex,
    List<String>? options,
  }) async {
    final result = await _client
        .from('template_items')
        .insert({
          'template_id': templateId,
          'section_id': sectionId,
          'question': question,
          'guidance': guidance,
          'response_type': responseType,
          'required': required,
          'weight': weight,
          'order_index': orderIndex,
          'options': options,
        })
        .select()
        .single();
    return TemplateItem.fromMap(result);
  }

  Future<void> updateItem(String id, {
    required String question,
    String? guidance,
    required String responseType,
    required bool required,
    required int weight,
    List<String>? options,
  }) async {
    await _client.from('template_items').update({
      'question': question,
      'guidance': guidance,
      'response_type': responseType,
      'required': required,
      'weight': weight,
      'options': options,
    }).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('template_items').delete().eq('id', id);
  }

  // ── Helpers de serialização para cache ─────────────
  //
  // AuditType e AuditTemplate não expõem toMap(), então reconstruímos os
  // mapas inline a partir dos campos públicos do modelo.

  Map<String, dynamic> _auditTypeToMap(AuditType t) => {
    'id': t.id,
    'name': t.name,
    'icon': t.icon,
    'color': t.color,
    'company_id': t.companyId,
    'active': true,
  };

  Map<String, dynamic> _auditTemplateToMap(AuditTemplate t) => {
    'id': t.id,
    'type_id': t.typeId,
    'name': t.name,
    'description': t.description,
    'company_id': t.companyId,
    'active': t.active,
    // Simula o join audit_types(name, icon) que AuditTemplate.fromMap espera
    'audit_types': {
      'name': t.typeName,
      'icon': t.typeIcon,
    },
  };
}
