import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/audit_item_image.dart';
import '../models/corrective_action.dart';
import '../services/company_context_service.dart';
import '../services/corrective_action_service.dart';
import '../services/image_service.dart';
import '../services/user_service.dart';
import 'corrective_actions_screen.dart' show CorrectiveActionStatusChip;

class CorrectiveActionDetailScreen extends StatefulWidget {
  final CorrectiveAction action;
  final String currentUserId;
  final String currentUserRole;

  const CorrectiveActionDetailScreen({
    super.key,
    required this.action,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<CorrectiveActionDetailScreen> createState() =>
      _CorrectiveActionDetailScreenState();
}

class _CorrectiveActionDetailScreenState
    extends State<CorrectiveActionDetailScreen> {
  final _service = CorrectiveActionService();
  final _userService = UserService();
  final _imageService = ImageService();
  late CorrectiveAction _action;
  bool _isTransitioning = false;

  List<AuditItemImage> _images = [];
  final Map<String, String> _signedUrls = {};

  // Campo inline de "ação tomada" — preenchido pelo responsável antes de submeter
  final _resolutionCtrl = TextEditingController();

  bool get _isAdmin =>
      AppRole.canAccessAdmin(widget.currentUserRole) ||
      AppRole.isSuperOrDev(widget.currentUserRole);
  bool get _isResponsible =>
      _action.responsibleUserId == widget.currentUserId;
  bool get _isCreator => _action.createdBy == widget.currentUserId;
  bool get _isAuditor => widget.currentUserRole == AppRole.auditor;
  bool get _canInteract => _isAdmin || _isResponsible || _isCreator;

  @override
  void initState() {
    super.initState();
    _action = widget.action;
    _resolutionCtrl.text = _action.resolutionNotes ?? '';
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final imgs = await _imageService.getImages(
        auditId: _action.auditId,
        itemId: _action.templateItemId,
        correctiveActionId: _action.id,
      );
      final urls = <String, String>{};
      await Future.wait(imgs.map((img) async {
        try {
          urls[img.id] = await _imageService.getSignedUrl(img.storagePath);
        } catch (_) {}
      }));
      if (mounted) setState(() { _images = imgs; _signedUrls.addAll(urls); });
    } catch (_) {}
  }

  void _openFullscreen(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              child: Center(
                child: InteractiveViewer(child: Image.network(url)),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool?> _confirm(String title, String body,
      {bool destructive = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.error)
                : null,
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _doTransition(String newStatus) async {
    // Para submeter para avaliação, exige "ação tomada" preenchida inline
    if (newStatus == 'em_avaliacao') {
      if (_resolutionCtrl.text.trim().isEmpty) {
        _snack('Descreva a ação tomada antes de enviar para avaliação.');
        return;
      }
    }

    if (newStatus == 'cancelada') {
      final ok = await _confirm(
        'Cancelar ação corretiva',
        'Esta ação será marcada como cancelada. Confirma?',
        destructive: true,
      );
      if (ok != true) return;
    } else if (newStatus == 'rejeitada') {
      final ok = await _confirm(
        'Rejeitar ação corretiva',
        'Confirma a rejeição? O responsável deverá corrigir ou abrir uma nova ação.',
        destructive: true,
      );
      if (ok != true) return;
    }

    setState(() => _isTransitioning = true);
    try {
      final notes = _resolutionCtrl.text.trim();
      await _service.updateStatus(
        _action.id,
        newStatus,
        resolutionNotes: notes.isNotEmpty ? notes : null,
      );
      if (!mounted) return;
      _snack('Status: ${CorrectiveActionStatus.fromDb(newStatus).label}');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Erro ao atualizar status. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  Future<void> _changeResponsible() async {
    final companyId = CompanyContextService.instance.activeCompanyId;
    if (companyId == null) {
      _snack('Empresa não selecionada.');
      return;
    }

    List<AppUser> users = [];
    try {
      users = await _userService.getByCompany(companyId);
    } catch (_) {
      _snack('Erro ao carregar usuários.');
      return;
    }

    if (!mounted) return;

    String? selectedId = _action.responsibleUserId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Alterar responsável'),
          content: DropdownButtonFormField<String>(
            value: selectedId,
            items: users
                .map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName)))
                .toList(),
            onChanged: (v) => setLocal(() => selectedId = v),
            decoration: const InputDecoration(
              labelText: 'Responsável',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedId == null) return;
    if (selectedId == _action.responsibleUserId) return;

    setState(() => _isTransitioning = true);
    try {
      await _service.updateResponsible(_action.id, selectedId!);
      if (!mounted) return;
      _snack('Responsável atualizado.');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Erro ao atualizar responsável.');
    } finally {
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  Future<void> _deleteAction() async {
    final ok = await _confirm(
      'Excluir ação corretiva',
      'Esta ação será excluída permanentemente. Isso não pode ser desfeito.',
      destructive: true,
    );
    if (ok != true) return;

    setState(() => _isTransitioning = true);
    try {
      await _service.deleteAction(_action.id);
      if (!mounted) return;
      _snack('Ação excluída.');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Erro ao excluir a ação.');
    } finally {
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final a = _action;
    final overdue = a.isOverdue;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Ação Corretiva',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Criador pode excluir (qualquer status)
          if (_isCreator || _isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Excluir ação',
              onPressed: _isTransitioning ? null : _deleteAction,
            ),
        ],
      ),
      body: _isTransitioning
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chip de status centralizado
                  Center(child: CorrectiveActionStatusChip(status: a.status)),
                  const SizedBox(height: 16),

                  // Card principal de informações
                  _buildInfoCard(t, a, overdue),
                  const SizedBox(height: 16),

                  // Fotos da não conformidade
                  if (_images.isNotEmpty) ...[
                    _buildPhotoCard(t),
                    const SizedBox(height: 16),
                  ],

                  // Campo inline "Ação tomada" — editável pelo responsável em em_andamento
                  if (!a.status.isFinal) _buildResolutionField(t, a),

                  // Botão alterar responsável — visível ao criador em status não-final
                  if ((_isAdmin || _isAuditor || _isResponsible || _isCreator) && !a.status.isFinal) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _changeResponsible,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Alterar responsável'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],

                  // Botões de transição — só para quem pode interagir
                  if (_canInteract && !a.status.isFinal) ...[
                    const SizedBox(height: 24),
                    ..._buildTransitionButtons(t, a),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(AppTheme t, CorrectiveAction a, bool overdue) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INFORMAÇÕES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: t.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Título', value: a.title, theme: t),
            _divider(t),
            _InfoRow(
                label: 'Responsável',
                value: a.responsibleName ?? a.responsibleUserId,
                theme: t),
            _divider(t),
            _InfoRow(
              label: 'Prazo',
              value: '${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}',
              theme: t,
              valueColor: overdue ? AppColors.error : null,
            ),
            if (a.description != null && a.description!.isNotEmpty) ...[
              _divider(t),
              _InfoRow(label: 'Descrição', value: a.description!, theme: t),
            ],
            // Ação tomada — exibida como read-only quando já preenchida e status é final ou em análise
            if (a.resolutionNotes != null &&
                a.resolutionNotes!.isNotEmpty &&
                (a.status.isFinal ||
                    a.status == CorrectiveActionStatus.emAnalise ||
                    a.status == CorrectiveActionStatus.emAvaliacao ||
                    a.status == CorrectiveActionStatus.reaberta)) ...[
              _divider(t),
              _InfoRow(label: 'Ação tomada', value: a.resolutionNotes!, theme: t),
            ],
            if (a.linkedAuditTitle != null) ...[
              _divider(t),
              _InfoRow(
                  label: 'Auditoria vinculada',
                  value: a.linkedAuditTitle!,
                  theme: t),
            ],
            _divider(t),
            _InfoRow(
              label: 'Criado em',
              value:
                  '${a.createdAt.day}/${a.createdAt.month}/${a.createdAt.year}',
              theme: t,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(AppTheme t) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOTOS DA NÃO CONFORMIDADE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: t.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _images.map((img) {
                  final url = _signedUrls[img.id];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: url != null ? () => _openFullscreen(url) : null,
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url != null
                              ? Image.network(url, fit: BoxFit.cover)
                              : Container(
                                  color: t.background,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionField(AppTheme t, CorrectiveAction a) {
    // Campo editável: responsável (ou auditor) nas fases onde cabe resposta
    final canEdit = (_isResponsible || _isAuditor) &&
        (a.status == CorrectiveActionStatus.aberta ||
            a.status == CorrectiveActionStatus.reaberta ||
            a.status == CorrectiveActionStatus.emAndamento); // legado

    if (!canEdit && (a.resolutionNotes == null || a.resolutionNotes!.isEmpty)) {
      return const SizedBox.shrink();
    }
    if (!canEdit) return const SizedBox.shrink(); // já exibido no card

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AÇÃO TOMADA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Obrigatório para enviar à avaliação.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _resolutionCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Descreva o que foi feito para resolver o problema…',
                hintStyle:
                    TextStyle(color: t.textSecondary, fontSize: 13),
                filled: true,
                fillColor: t.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: t.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: t.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppTheme t) => Divider(height: 16, color: t.divider);

  List<Widget> _buildTransitionButtons(AppTheme t, CorrectiveAction a) {
    final buttons = <Widget>[];

    void add(String newStatus, String label, {bool destructive = false}) {
      if (!CorrectiveActionService.canTransitionTo(
        newStatus: newStatus,
        action: a,
        role: widget.currentUserRole,
        userId: widget.currentUserId,
      )) { return; }

      buttons.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: destructive
            ? OutlinedButton(
                onPressed: () => _doTransition(newStatus),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label),
              )
            : ElevatedButton(
                onPressed: () => _doTransition(newStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label),
              ),
      ));
    }

    switch (a.status) {
      // Novo fluxo
      case CorrectiveActionStatus.aberta:
        add('em_analise', 'Enviar resposta');
        add('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.emAnalise:
        add('finalizada', 'Finalizar');
        add('reaberta', 'Rejeitar', destructive: true);
        break;
      case CorrectiveActionStatus.reaberta:
        add('em_analise', 'Reenviar para análise');
        add('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.finalizada:
      case CorrectiveActionStatus.cancelada:
        break;
      // Legado — ações antigas com status antigos continuam funcionando
      case CorrectiveActionStatus.emAndamento:
        add('em_analise', 'Enviar para análise');
        add('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.emAvaliacao:
        add('finalizada', 'Finalizar');
        add('reaberta', 'Rejeitar', destructive: true);
        break;
      case CorrectiveActionStatus.rejeitada:
        add('em_analise', 'Reenviar para análise');
        add('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.aprovada:
        break;
    }

    if (buttons.isEmpty) return [];

    return [
      Text(
        'AÇÕES DISPONÍVEIS',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: t.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 12),
      ...buttons,
    ];
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppTheme theme;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? t.textPrimary,
            )),
      ],
    );
  }
}
