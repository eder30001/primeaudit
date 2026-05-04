import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_template_service.dart';
import 'checklist_template_form_screen.dart';

/// Tela principal do módulo de Checklist.
///
/// Exibe 3 abas: Industrial, Transportadora e Meus checklists.
/// Seeds (is_padrao = true) mostram badge 'Padrão' e ícone de cópia.
/// Templates próprios mostram badge 'Personalizado' e PopupMenuButton (Editar/Clonar/Excluir).
class ChecklistTemplatesScreen extends StatefulWidget {
  const ChecklistTemplatesScreen({super.key});

  @override
  State<ChecklistTemplatesScreen> createState() =>
      _ChecklistTemplatesScreenState();
}

class _ChecklistTemplatesScreenState extends State<ChecklistTemplatesScreen>
    with TickerProviderStateMixin {
  final _service = ChecklistTemplateService();
  late TabController _tabController;
  List<ChecklistTemplate> _industrial = [];
  List<ChecklistTemplate> _transportadora = [];
  List<ChecklistTemplate> _owned = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getByCategory('industrial'),
        _service.getByCategory('transportadora'),
        _service.getOwned(),
      ]);
      if (mounted) {
        setState(() {
          _industrial = results[0];
          _transportadora = results[1];
          _owned = results[2];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = 'Erro ao carregar templates. Puxe para atualizar.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreate() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (_) => const ChecklistTemplateFormScreen()),
        )
        .then((_) => _load());
  }

  void _openEdit(ChecklistTemplate t) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (_) => ChecklistTemplateFormScreen(editing: t)),
        )
        .then((_) => _load());
  }

  Future<void> _confirmDelete(ChecklistTemplate t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir checklist'),
        content: Text(
            'Excluir "${t.name}"? Todos os itens serão removidos e essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir checklist'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await _service.deleteTemplate(t.id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Checklist excluído.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao excluir. Tente novamente.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCloneSheet(ChecklistTemplate t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CloneBottomSheet(
        template: t,
        service: _service,
        parentContext: context,
        onAfterClone: _load,
      ),
    );
  }

  Widget _buildTabContent(List<ChecklistTemplate> templates, String tab) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (templates.isEmpty) {
      return _buildEmptyState(tab);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: templates.length,
        itemBuilder: (_, i) => _ChecklistTemplateCard(
          template: templates[i],
          currentUserId: _currentUserId,
          onDelete: () => _confirmDelete(templates[i]),
          onEdit: () => _openEdit(templates[i]),
          onClone: () => _showCloneSheet(templates[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String tab) {
    IconData icon;
    String heading;
    String body;

    switch (tab) {
      case 'industrial':
        icon = Icons.factory_outlined;
        heading = 'Nenhum template disponível';
        body = 'Os templates padrão serão carregados em breve.';
        break;
      case 'transportadora':
        icon = Icons.local_shipping_outlined;
        heading = 'Nenhum template disponível';
        body = 'Os templates padrão serão carregados em breve.';
        break;
      default: // 'meus'
        icon = Icons.checklist_rounded;
        heading = 'Nenhum checklist criado';
        body = 'Crie um checklist personalizado ou clone um template existente.';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.of(context).textSecondary),
          const SizedBox(height: 12),
          Text(
            heading,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.of(context).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Checklist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.factory_outlined), text: 'Industrial'),
            Tab(
                icon: Icon(Icons.local_shipping_outlined),
                text: 'Transportadora'),
            Tab(
                icon: Icon(Icons.person_outline_rounded),
                text: 'Meus checklists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(_industrial, 'industrial'),
          _buildTabContent(_transportadora, 'transportadora'),
          _buildTabContent(_owned, 'meus'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Novo checklist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── _ChecklistTemplateCard ────────────────────────────────────────────────────

class _ChecklistTemplateCard extends StatelessWidget {
  final ChecklistTemplate template;
  final String? currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Future<void> Function() onClone;

  const _ChecklistTemplateCard({
    required this.template,
    required this.currentUserId,
    required this.onDelete,
    required this.onEdit,
    required this.onClone,
  });

  Color get _categoryColor {
    switch (template.category) {
      case 'industrial':
        return Colors.orange;
      case 'transportadora':
        return const Color(0xFF1565C0);
      default:
        return AppColors.accent;
    }
  }

  IconData get _categoryIcon {
    switch (template.category) {
      case 'industrial':
        return Icons.factory_outlined;
      case 'transportadora':
        return Icons.local_shipping_outlined;
      default:
        return Icons.checklist_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final isOwn =
        template.createdBy == currentUserId && !template.isSeed;

    Widget trailing;
    if (template.isSeed) {
      trailing = IconButton(
        icon: Icon(Icons.copy_outlined, size: 20, color: t.textSecondary),
        tooltip: 'Clonar template',
        onPressed: onClone,
      );
    } else if (isOwn) {
      trailing = PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: t.textSecondary),
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'clone') onClone();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Editar'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'clone',
            child: Row(
              children: [
                Icon(Icons.copy_outlined, size: 18),
                SizedBox(width: 8),
                Text('Clonar'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Text('Excluir',
                    style: const TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      );
    } else {
      trailing = Icon(Icons.chevron_right_rounded, color: t.textSecondary);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.divider),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _categoryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_categoryIcon, size: 22, color: _categoryColor),
        ),
        title: Text(
          template.name,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (template.description != null)
              Text(
                template.description!,
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (template.isSeed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Padrão',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                if (isOwn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Personalizado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: trailing,
        onTap: () {
          if (template.isSeed) {
            onClone();
          } else if (isOwn) {
            onEdit();
          }
        },
      ),
    );
  }
}

// ── _CloneBottomSheet ─────────────────────────────────────────────────────────

class _CloneBottomSheet extends StatefulWidget {
  final ChecklistTemplate template;
  final ChecklistTemplateService service;
  final BuildContext parentContext;
  final VoidCallback onAfterClone;

  const _CloneBottomSheet({
    required this.template,
    required this.service,
    required this.parentContext,
    required this.onAfterClone,
  });

  @override
  State<_CloneBottomSheet> createState() => _CloneBottomSheetState();
}

class _CloneBottomSheetState extends State<_CloneBottomSheet> {
  bool _isCloning = false;

  Future<void> _clone() async {
    // Capture ScaffoldMessenger reference before any async gap (use_build_context_synchronously).
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    setState(() => _isCloning = true);
    try {
      await widget.service.cloneTemplate(widget.template);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Checklist clonado com sucesso. Acesse "Meus checklists".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAfterClone();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Erro ao clonar. Tente novamente.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.copy_outlined, color: t.textPrimary),
              const SizedBox(width: 12),
              Text(
                'Clonar template',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Clonar "${widget.template.name}" para Meus checklists?',
            style: TextStyle(fontSize: 14, color: t.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Você poderá editar os itens depois.',
            style: TextStyle(fontSize: 12, color: t.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isCloning ? null : _clone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isCloning
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Text(
                      'Clonar checklist',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: t.textSecondary),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}
