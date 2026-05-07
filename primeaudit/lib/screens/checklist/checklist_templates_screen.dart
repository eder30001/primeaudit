import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_template_service.dart';
import 'checklist_template_form_screen.dart';

/// Gerenciamento de templates de checklist.
///
/// Lista todos os templates visíveis ao usuário (seeds + próprios).
/// Seeds mostram botão Clonar. Templates próprios mostram Editar/Excluir.
class ChecklistTemplatesScreen extends StatefulWidget {
  const ChecklistTemplatesScreen({super.key});

  @override
  State<ChecklistTemplatesScreen> createState() =>
      _ChecklistTemplatesScreenState();
}

class _ChecklistTemplatesScreenState extends State<ChecklistTemplatesScreen> {
  final _service = ChecklistTemplateService();
  List<ChecklistTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _load();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _service.getAll();
      if (mounted) setState(() => _templates = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar templates.\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChecklistTemplate> get _filtered {
    if (_searchQuery.isEmpty) return _templates;
    return _templates.where((t) =>
      t.name.toLowerCase().contains(_searchQuery) ||
      (t.description?.toLowerCase().contains(_searchQuery) ?? false),
    ).toList();
  }

  void _openCreate() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ChecklistTemplateFormScreen(),
    )).then((_) => _load());
  }

  void _openEdit(ChecklistTemplate t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChecklistTemplateFormScreen(editing: t),
    )).then((_) => _load());
  }

  Future<void> _confirmDelete(ChecklistTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir template'),
        content: Text('Deseja excluir "${t.name}"?\nEssa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteTemplate(t.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $e'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  Future<void> _clone(ChecklistTemplate t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.cloneTemplate(t);
      _load();
      messenger.showSnackBar(const SnackBar(
        content: Text('Template clonado com sucesso.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Erro ao clonar. Tente novamente.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Templates de checklist',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo template',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: t.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar templates…',
                hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: t.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: t.textSecondary, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: t.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          Expanded(child: _buildBody(t, filtered)),
        ],
      ),
    );
  }

  Widget _buildBody(AppTheme t, List<ChecklistTemplate> templates) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: t.textSecondary),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 56, color: t.textSecondary),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Nenhum template encontrado'
                    : 'Nenhum template ainda',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Tente ajustar a busca.'
                    : 'Crie o primeiro template para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: templates.length,
        itemBuilder: (_, i) {
          final tpl = templates[i];
          final isOwn = tpl.createdBy == _currentUserId;
          final isSeed = tpl.isPadrao;
          return _TemplateCard(
            template: tpl,
            isOwn: isOwn,
            isSeed: isSeed,
            onEdit: isOwn ? () => _openEdit(tpl) : null,
            onDelete: isOwn ? () => _confirmDelete(tpl) : null,
            onClone: () => _clone(tpl),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de template
// ---------------------------------------------------------------------------
class _TemplateCard extends StatelessWidget {
  final ChecklistTemplate template;
  final bool isOwn;
  final bool isSeed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onClone;

  const _TemplateCard({
    required this.template,
    required this.isOwn,
    required this.isSeed,
    required this.onEdit,
    required this.onDelete,
    required this.onClone,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.checklist_rounded,
                  size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      if (isSeed)
                        _Badge(label: 'Padrão', color: AppColors.accent),
                      if (isOwn && !isSeed)
                        _Badge(label: 'Próprio', color: AppColors.primary),
                    ],
                  ),
                  if (template.description != null &&
                      template.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      template.description!,
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (template.category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      template.category,
                      style: TextStyle(
                          fontSize: 11,
                          color: t.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 20, color: t.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'delete') onDelete?.call();
                if (v == 'clone') onClone();
              },
              itemBuilder: (_) => [
                if (isOwn) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ]),
                  ),
                ],
                const PopupMenuItem(
                  value: 'clone',
                  child: Row(children: [
                    Icon(Icons.copy_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Clonar'),
                  ]),
                ),
                if (isOwn) ...[
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
