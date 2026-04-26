import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../models/audit_template.dart';
import '../models/app_user.dart';
import '../services/corrective_action_service.dart';
import '../services/user_service.dart';
import '../services/company_context_service.dart';

class CreateCorrectiveActionScreen extends StatefulWidget {
  final Audit audit;
  final TemplateItem item;

  const CreateCorrectiveActionScreen({
    super.key,
    required this.audit,
    required this.item,
  });

  @override
  State<CreateCorrectiveActionScreen> createState() =>
      _CreateCorrectiveActionScreenState();
}

class _CreateCorrectiveActionScreenState
    extends State<CreateCorrectiveActionScreen> {
  final _service = CorrectiveActionService();
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<AppUser> _users = [];
  AppUser? _selectedUser;
  DateTime? _dueDate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final companyId = CompanyContextService.instance.activeCompanyId;
    if (companyId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Empresa não selecionada';
      });
      return;
    }
    try {
      final users = await _userService.getByCompany(companyId);
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erro ao carregar usuários. Tente novamente.';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      _snack('Selecione o prazo');
      return;
    }
    if (_selectedUser == null) {
      _snack('Selecione o responsável');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final companyId = CompanyContextService.instance.activeCompanyId!;
      final currentUser = Supabase.instance.client.auth.currentUser!;
      await _service.createAction(
        auditId: widget.audit.id,
        templateItemId: widget.item.id,
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        responsibleUserId: _selectedUser!.id,
        dueDate: _dueDate!,
        companyId: companyId,
        createdBy: currentUser.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Erro ao criar ação. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Ação Corretiva'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: t.textPrimary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _buildForm(t),
    );
  }

  Widget _buildForm(AppTheme t) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner pergunta vinculada
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pergunta vinculada',
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.question,
                    style: TextStyle(fontSize: 14, color: t.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Título
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Título',
                hintText: 'Descreva brevemente o problema',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'O título é obrigatório' : null,
            ),
            const SizedBox(height: 16),

            // Responsável
            DropdownButtonFormField<String>(
              value: _selectedUser?.id,
              hint: const Text('Selecione o responsável'),
              items: _users
                  .map((u) =>
                      DropdownMenuItem(value: u.id, child: Text(u.fullName)))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedUser = val == null
                    ? null
                    : _users.firstWhere((u) => u.id == val);
              }),
              validator: (val) =>
                  val == null ? 'Selecione o responsável' : null,
              decoration: InputDecoration(
                labelText: 'Responsável',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prazo
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: _dueDate == null
                    ? ''
                    : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
              ),
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'Prazo',
                hintText: 'Selecione a data limite',
                suffixIcon: const Icon(Icons.calendar_today_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              validator: (_) {
                if (_dueDate == null) return 'Selecione o prazo';
                if (_dueDate!.isBefore(DateTime.now())) {
                  return 'O prazo deve ser uma data futura';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descrição / Observação',
                hintText: 'Detalhes adicionais (opcional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botão submit
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Criar ação'),
            ),
          ],
        ),
      ),
    );
  }
}
