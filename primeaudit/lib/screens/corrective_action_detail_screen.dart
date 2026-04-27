import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/corrective_action.dart';
import '../services/corrective_action_service.dart';
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
  bool _isTransitioning = false;
  late CorrectiveAction _action;

  @override
  void initState() {
    super.initState();
    _action = widget.action;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool?> _confirmTransition(String title, String body) {
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askResolutionNotes() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ação tomada'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Descreva o que foi feito para resolver o problema…',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _doTransition(String newStatus) async {
    String? resolutionNotes;

    if (newStatus == 'em_avaliacao') {
      resolutionNotes = await _askResolutionNotes();
      if (resolutionNotes == null) return; // usuário cancelou
    } else if (newStatus == 'cancelada') {
      final confirmed = await _confirmTransition(
        'Cancelar ação corretiva',
        'Esta ação será marcada como cancelada. Confirma?',
      );
      if (confirmed != true) return;
    } else if (newStatus == 'rejeitada') {
      final confirmed = await _confirmTransition(
        'Rejeitar ação corretiva',
        'Confirma a rejeição desta ação? O responsável deverá corrigi-la ou abrir uma nova ação.',
      );
      if (confirmed != true) return;
    }

    setState(() => _isTransitioning = true);
    try {
      await _service.updateStatus(_action.id, newStatus,
          resolutionNotes: resolutionNotes);
      if (!mounted) return;
      _snack(
          'Status atualizado para ${CorrectiveActionStatus.fromDb(newStatus).label}');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Erro ao atualizar status. Tente novamente.');
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
      ),
      body: _isTransitioning
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: CorrectiveActionStatusChip(status: a.status)),
                  const SizedBox(height: 16),
                  _buildInfoCard(t, a, overdue),
                  const SizedBox(height: 24),
                  ..._buildTransitionButtons(t, a),
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
              'INFORMAÇÕES DA AÇÃO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textSecondary,
                letterSpacing: 0.5,
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
              value:
                  '${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}',
              theme: t,
              valueColor: overdue ? AppColors.error : null,
            ),
            if (a.description != null && a.description!.isNotEmpty) ...[
              _divider(t),
              _InfoRow(
                  label: 'Descrição / Observação',
                  value: a.description!,
                  theme: t),
            ],
            if (a.resolutionNotes != null && a.resolutionNotes!.isNotEmpty) ...[
              _divider(t),
              _InfoRow(
                  label: 'Ação tomada',
                  value: a.resolutionNotes!,
                  theme: t),
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
              label: 'Data de criação',
              value:
                  '${a.createdAt.day}/${a.createdAt.month}/${a.createdAt.year}',
              theme: t,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppTheme t) => Divider(height: 16, color: t.divider);

  List<Widget> _buildTransitionButtons(AppTheme t, CorrectiveAction a) {
    if (a.status.isFinal) return [];

    final buttons = <Widget>[];

    void addButton(String newStatus, String label,
        {bool destructive = false}) {
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
      case CorrectiveActionStatus.aberta:
        addButton('em_andamento', 'Iniciar ação');
        addButton('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.emAndamento:
        addButton('em_avaliacao', 'Enviar para avaliação');
        addButton('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.emAvaliacao:
        addButton('aprovada', 'Aprovar');
        addButton('rejeitada', 'Rejeitar ação', destructive: true);
        addButton('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.rejeitada:
        addButton('em_andamento', 'Iniciar ação');
        addButton('cancelada', 'Cancelar ação', destructive: true);
        break;
      case CorrectiveActionStatus.aprovada:
      case CorrectiveActionStatus.cancelada:
        break;
    }

    if (buttons.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Você não tem permissão para alterar o status desta ação.',
            style: TextStyle(fontSize: 13, color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    return [
      Text(
        'AÇÕES DISPONÍVEIS',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.textSecondary,
          letterSpacing: 0.5,
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
