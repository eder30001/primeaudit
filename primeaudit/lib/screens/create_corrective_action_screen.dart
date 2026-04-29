import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../models/audit_item_image.dart';
import '../models/audit_template.dart';
import '../models/app_user.dart';
import '../services/corrective_action_service.dart';
import '../services/image_service.dart';
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
  final _imageService = ImageService();
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();

  List<AppUser> _users = [];
  AppUser? _selectedUser;
  DateTime? _dueDate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final List<_PhotoEntry> _photos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
        title: widget.item.question,
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

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(
        source: source, imageQuality: 85, maxWidth: 1200);
    if (file == null) return;

    final key = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _photos.add(_PhotoEntry(key: key, state: _PhotoState.uploading, file: file)));

    try {
      final companyId = CompanyContextService.instance.activeCompanyId!;
      final img = await _imageService.uploadImage(
        companyId: companyId,
        auditId: widget.audit.id,
        itemId: widget.item.id,
        file: file,
      );
      final url = await _imageService.getSignedUrl(img.storagePath);
      if (!mounted) return;
      setState(() {
        final i = _photos.indexWhere((p) => p.key == key);
        if (i >= 0) _photos[i] = _photos[i].copyWith(state: _PhotoState.uploaded, image: img, signedUrl: url);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _photos.indexWhere((p) => p.key == key);
        if (i >= 0) _photos[i] = _photos[i].copyWith(state: _PhotoState.error);
      });
      _snack('Erro ao enviar foto — toque na miniatura para tentar novamente.');
    }
  }

  Future<void> _retryPhoto(String key) async {
    final entry = _photos.firstWhere((p) => p.key == key);
    if (entry.file == null) return;
    setState(() {
      final i = _photos.indexWhere((p) => p.key == key);
      if (i >= 0) _photos[i] = _photos[i].copyWith(state: _PhotoState.uploading);
    });
    try {
      final companyId = CompanyContextService.instance.activeCompanyId!;
      final img = await _imageService.uploadImage(
        companyId: companyId,
        auditId: widget.audit.id,
        itemId: widget.item.id,
        file: entry.file!,
      );
      final url = await _imageService.getSignedUrl(img.storagePath);
      if (!mounted) return;
      setState(() {
        final i = _photos.indexWhere((p) => p.key == key);
        if (i >= 0) _photos[i] = _photos[i].copyWith(state: _PhotoState.uploaded, image: img, signedUrl: url);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _photos.indexWhere((p) => p.key == key);
        if (i >= 0) _photos[i] = _photos[i].copyWith(state: _PhotoState.error);
      });
    }
  }

  Future<void> _removePhoto(String key) async {
    final entry = _photos.firstWhere((p) => p.key == key);
    setState(() => _photos.removeWhere((p) => p.key == key));
    if (entry.image != null) {
      try {
        await _imageService.deleteImage(
            imageId: entry.image!.id, storagePath: entry.image!.storagePath);
      } catch (_) {}
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

  Widget _buildPhotoSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos da não conformidade',
            style: TextStyle(fontSize: 13, color: t.textSecondary)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    size: 22, color: AppColors.accent),
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _photos
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _buildThumb(p),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildThumb(_PhotoEntry p) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: p.state == _PhotoState.error ? () => _retryPhoto(p.key) : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (p.state == _PhotoState.uploaded && p.signedUrl != null)
                Image.network(p.signedUrl!, fit: BoxFit.cover)
              else if (p.file != null)
                Opacity(
                  opacity: p.state == _PhotoState.error ? 0.4 : 0.6,
                  child: Image.file(File(p.file!.path), fit: BoxFit.cover),
                )
              else
                Container(color: AppTheme.of(context).background),
              if (p.state == _PhotoState.uploading)
                const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))),
              if (p.state == _PhotoState.error)
                const Center(
                    child: Icon(Icons.error_rounded,
                        color: AppColors.error, size: 20)),
              if (p.state == _PhotoState.uploaded)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _removePhoto(p.key),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
            // Pergunta vinculada (será o título da ação)
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
                    'Título da ação (pergunta vinculada)',
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.question,
                    style: TextStyle(
                        fontSize: 14,
                        color: t.textPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
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
            const SizedBox(height: 16),

            // Fotos da não conformidade
            _buildPhotoSection(t),

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

// ---------------------------------------------------------------------------
// Tipos auxiliares para upload de fotos
// ---------------------------------------------------------------------------
enum _PhotoState { uploading, uploaded, error }

class _PhotoEntry {
  final String key;
  final _PhotoState state;
  final XFile? file;
  final AuditItemImage? image;
  final String? signedUrl;

  const _PhotoEntry({
    required this.key,
    required this.state,
    this.file,
    this.image,
    this.signedUrl,
  });

  _PhotoEntry copyWith({
    _PhotoState? state,
    AuditItemImage? image,
    String? signedUrl,
  }) =>
      _PhotoEntry(
        key: key,
        state: state ?? this.state,
        file: file,
        image: image ?? this.image,
        signedUrl: signedUrl ?? this.signedUrl,
      );
}

// ---------------------------------------------------------------------------
// Bottom sheet para escolha de fonte
// ---------------------------------------------------------------------------
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading:
              const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
          title: const Text('Tirar foto', style: TextStyle(fontSize: 14)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading:
              const Icon(Icons.photo_library_rounded, color: AppColors.accent),
          title:
              const Text('Escolher da galeria', style: TextStyle(fontSize: 14)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
