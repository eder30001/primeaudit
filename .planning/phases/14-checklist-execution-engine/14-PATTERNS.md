# Phase 14: Checklist Execution Engine — Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 6 new/modified files
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `primeaudit/supabase/migrations/20260506_create_checklist_executions.sql` | migration | CRUD | `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` | exact |
| `primeaudit/supabase/migrations/20260506_add_options_to_checklist_template_items.sql` | migration | transform | `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` (ADD COLUMN pattern) | exact |
| `primeaudit/lib/models/checklist_execution.dart` | model | request-response | `primeaudit/lib/models/audit.dart` | exact |
| `primeaudit/lib/services/checklist_execution_service.dart` | service | CRUD | `primeaudit/lib/services/audit_service.dart` | exact |
| `primeaudit/lib/services/checklist_answer_service.dart` | service | CRUD | `primeaudit/lib/services/audit_answer_service.dart` | exact |
| `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` | screen | event-driven | `primeaudit/lib/screens/audit_execution_screen.dart` | exact |

---

## Pattern Assignments

### `primeaudit/supabase/migrations/20260506_create_checklist_executions.sql` (migration, CRUD)

**Analog:** `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql`

**File header / idempotency declaration pattern** (lines 1-6):
```sql
-- =============================================================================
-- Migração: checklist_executions e checklist_answers
-- Data: 2026-05-06
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- Tabelas novas; zero alterações em audits / audit_answers.
-- =============================================================================
```

**CREATE TABLE + ADD COLUMN idempotent pattern** (lines 12-21):
```sql
CREATE TABLE IF NOT EXISTS checklist_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS name        TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS category    TEXT        NOT NULL DEFAULT 'industrial';
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS is_padrao   BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS company_id  UUID;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_by  UUID;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW();
```
Apply same shape to `checklist_executions` and `checklist_answers`. Note the `NOT NULL DEFAULT gen_random_uuid()` trick on FK columns (line 49 in analog) when the table may already have rows.

**DROP/ADD constraint idempotent pattern** (lines 27-37):
```sql
ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_category_check;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_category_check
  CHECK (category IN ('industrial', 'transportadora'));

ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_company_id_fkey;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL;
```
Apply to `checklist_executions` constraints:
- `checklist_executions_status_check` → `CHECK (status IN ('rascunho', 'concluido'))`
- `checklist_executions_template_id_fkey` → `REFERENCES checklist_templates(id) ON DELETE RESTRICT`
- `checklist_executions_company_id_fkey` → `REFERENCES companies(id) ON DELETE SET NULL`
- `checklist_executions_created_by_fkey` → `REFERENCES profiles(id) ON DELETE SET NULL`
- `checklist_answers_execution_id_fkey` → `REFERENCES checklist_executions(id) ON DELETE CASCADE`
- `checklist_answers_item_id_fkey` → `REFERENCES checklist_template_items(id) ON DELETE CASCADE`
- `checklist_answers_execution_item_unique` → `UNIQUE (execution_id, item_id)` — required for upsert onConflict

**Index pattern** (lines 71-73):
```sql
CREATE INDEX IF NOT EXISTS idx_checklist_templates_category   ON checklist_templates (category);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_created_by ON checklist_templates (created_by);
CREATE INDEX IF NOT EXISTS idx_checklist_template_items_tmpl  ON checklist_template_items (template_id, order_index);
```
Apply naming: `idx_checklist_executions_created_by`, `idx_checklist_executions_template_id`, `idx_checklist_executions_company_status`, `idx_checklist_answers_execution_id`.

**RLS Pattern 1 — superuser/dev full access** (lines 81-84):
```sql
ALTER TABLE checklist_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_checklist_templates_full" ON checklist_templates;
CREATE POLICY "superuser_dev_checklist_templates_full" ON checklist_templates
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));
```

**RLS Pattern 2 — company + creator scope for executions:**
```sql
-- SELECT: auditor sees own; adm sees all company
DROP POLICY IF EXISTS "checklist_executions_select" ON checklist_executions;
CREATE POLICY "checklist_executions_select" ON checklist_executions FOR SELECT
  USING (
    get_my_role() IN ('adm') AND company_id = get_my_company_id()
    OR created_by = auth.uid()
  );

-- INSERT: only own records
DROP POLICY IF EXISTS "checklist_executions_insert" ON checklist_executions;
CREATE POLICY "checklist_executions_insert" ON checklist_executions FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- UPDATE: only own records
DROP POLICY IF EXISTS "checklist_executions_update" ON checklist_executions;
CREATE POLICY "checklist_executions_update" ON checklist_executions FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());
```

**RLS Pattern 3 — subquery via FK for answers** (lines 113-151):
```sql
DROP POLICY IF EXISTS "authenticated_checklist_template_items_select" ON checklist_template_items;
CREATE POLICY "authenticated_checklist_template_items_select" ON checklist_template_items FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND (t.is_padrao = true OR t.created_by = auth.uid())
    )
  );
```
For `checklist_answers`, replace subquery to check `checklist_executions` instead:
```sql
EXISTS (
  SELECT 1 FROM checklist_executions e
  WHERE e.id = checklist_answers.execution_id
    AND e.created_by = auth.uid()
)
```

**NOTIFY at end** (line 263):
```sql
NOTIFY pgrst, 'reload schema';
```

---

### `primeaudit/supabase/migrations/20260506_add_options_to_checklist_template_items.sql` (migration, transform)

**Analog:** ADD COLUMN pattern from `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` (lines 15-22)

This is a one-statement migration. Full file:
```sql
-- =============================================================================
-- Migração: adiciona coluna options em checklist_template_items
-- Data: 2026-05-06
-- Idempotente: ADD COLUMN IF NOT EXISTS não falha em re-execução.
-- =============================================================================

ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS options TEXT[];

NOTIFY pgrst, 'reload schema';
```

No DROP/ADD constraint needed — `TEXT[]` nullable column has no CHECK constraint.

---

### `primeaudit/lib/models/checklist_execution.dart` (model, request-response)

**Analog:** `primeaudit/lib/models/audit.dart`

**Imports pattern** (audit.dart lines 1-1):
```dart
import 'package:flutter/material.dart';
```
`ChecklistExecution` needs no `Color`/`IconData` display getters if status is simple (`rascunho`/`concluido`). Import `material.dart` only if adding status color getters.

**Enum pattern** (audit.dart lines 3-39):
```dart
enum AuditStatus {
  rascunho,
  emAndamento,
  concluida,
  atrasada,
  cancelada;

  String get label {
    switch (this) {
      case rascunho:    return 'Rascunho';
      case concluida:   return 'Concluída';
      // ...
    }
  }

  Color get color { ... }
  IconData get icon { ... }
}
```
For checklist, use simpler 2-value enum `ChecklistExecutionStatus { rascunho, concluido }` with `label` and `color` getters only.

**Model constructor pattern** (audit.dart lines 65-85):
```dart
const Audit({
  required this.id,
  required this.title,
  // ...
  this.perimeterId,          // optional field: no `required`
  this.conformityPercent,    // nullable Double
});
```

**fromMap factory pattern** (audit.dart lines 87-109):
```dart
factory Audit.fromMap(Map<String, dynamic> map) {
  return Audit(
    id: map['id'],
    templateId: map['template_id'],
    templateName: map['audit_templates']?['name'] ?? '',   // joined table, null-safe
    companyId: map['company_id'],
    auditorId: map['auditor_id'],
    createdAt: DateTime.parse(map['created_at']).toLocal(),
    deadline: map['deadline'] != null ? _parseDateOnly(map['deadline']) : null,
    status: _statusFromString(map['status']),
    conformityPercent: (map['conformity_percent'] as num?)?.toDouble(),
  );
}
```
Key adaptations for `ChecklistExecution.fromMap`:
- `templateName: map['checklist_templates']?['name'] ?? ''` (joined via `.select('*, checklist_templates(name)')`)
- `dataExecucao: DateTime.parse(map['data_execucao'])` — DATE column, no `.toLocal()` (no timezone conversion needed — same pitfall as `_parseDateOnly` in audit.dart line 115)
- `conformityPercent: (map['conformity_percent'] as num?)?.toDouble()`
- `completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']).toLocal() : null`

**Static helper pattern** (audit.dart lines 115-131):
```dart
static DateTime _parseDateOnly(String s) {
  final dt = DateTime.parse(s);
  final utc = dt.isUtc ? dt : dt.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

static AuditStatus _statusFromString(String? s) {
  switch (s) {
    case 'concluida': return AuditStatus.concluida;
    default:          return AuditStatus.rascunho;
  }
}
```

**Computed getter pattern** (audit.dart lines 133-138):
```dart
bool get isOverdue => status == AuditStatus.atrasada || ...;
```
For checklist: `bool get isConcluido => status == ChecklistExecutionStatus.concluido;`

**`ChecklistTemplateItem` modification** — add `options` field to existing `primeaudit/lib/models/checklist_template.dart` (ChecklistTemplateItem, lines 49-73):
```dart
// Current fromMap (lines 64-72):
factory ChecklistTemplateItem.fromMap(Map<String, dynamic> map) {
  return ChecklistTemplateItem(
    id: map['id'],
    templateId: map['template_id'],
    description: map['description'] ?? '',
    itemType: map['item_type'] ?? 'yes_no',
    orderIndex: map['order_index'] ?? 0,
  );
}
```
Add to constructor: `this.options = const [],`
Add to fromMap: `options: (map['options'] as List?)?.cast<String>() ?? [],`

---

### `primeaudit/lib/services/checklist_execution_service.dart` (service, CRUD)

**Analog:** `primeaudit/lib/services/audit_service.dart`

**Imports + client declaration pattern** (audit_service.dart lines 1-19):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit.dart';

class AuditService {
  final _client = Supabase.instance.client;

  static const _select = '''
    *,
    audit_types(name, icon, color),
    audit_templates(name),
    companies(name, requires_perimeter),
    perimeters(name),
    auditor:profiles!auditor_id(full_name)
  ''';
```
For `ChecklistExecutionService`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_execution.dart';

class ChecklistExecutionService {
  final _client = Supabase.instance.client;

  static const _select = '''
    *,
    checklist_templates(name)
  ''';
```

**createX pattern** (audit_service.dart lines 42-66):
```dart
Future<Audit> createAudit({
  required String title,
  required String auditTypeId,
  required String templateId,
  required String companyId,
  String? perimeterId,
  required String auditorId,
  DateTime? deadline,
}) async {
  final result = await _client
      .from('audits')
      .insert({
        'title': title,
        'audit_type_id': auditTypeId,
        'template_id': templateId,
        'company_id': companyId,
        'perimeter_id': perimeterId,
        'auditor_id': auditorId,
        'deadline': deadline?.toIso8601String(),
        'status': 'em_andamento',
      })
      .select(_select)
      .single();
  return Audit.fromMap(result);
}
```
For `createExecution`, obtain `userId` from `_client.auth.currentUser!.id` and format `data_execucao` as `'yyyy-MM-dd'` without `intl` dependency: `dataExecucao.toIso8601String().substring(0, 10)`.

**finalizeX pattern** (audit_service.dart lines 107-116):
```dart
Future<void> finalizeAudit({
  required String id,
  required double conformityPercent,
}) async {
  await _client.from('audits').update({
    'status': 'concluida',
    'conformity_percent': conformityPercent,
    'completed_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}
```

**deleteX pattern** (audit_service.dart lines 102-104):
```dart
Future<void> deleteAudit(String id) async {
  await _client.from('audits').delete().eq('id', id);
}
```

---

### `primeaudit/lib/services/checklist_answer_service.dart` (service, CRUD)

**Analog:** `primeaudit/lib/services/audit_answer_service.dart`

**Full file pattern** (audit_answer_service.dart lines 1-82) — copy entire structure:

**Imports + class declaration** (lines 1-11):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_answer.dart';
import '../models/audit_template.dart';

class AuditAnswerService {
  final _client = Supabase.instance.client;
```
Replace imports with checklist models. No `audit_answer.dart` analog needed — answers are retrieved as raw maps and loaded directly into `Map<String, String>` in the screen (pattern from `_load()` in audit_execution_screen.dart lines 104-109).

**getAnswers pattern** (audit_answer_service.dart lines 13-19):
```dart
Future<List<AuditAnswer>> getAnswers(String auditId) async {
  final data = await _client
      .from('audit_answers')
      .select()
      .eq('audit_id', auditId)
      .order('answered_at');
  return (data as List).map((e) => AuditAnswer.fromMap(e)).toList();
}
```
For checklist, return `List<Map<String, dynamic>>` directly (no `ChecklistAnswer` model needed — screen maps directly to `_answers[e['item_id']] = e['response']`):
```dart
Future<List<Map<String, dynamic>>> getAnswers(String executionId) async {
  final data = await _client
      .from('checklist_answers')
      .select()
      .eq('execution_id', executionId)
      .order('answered_at');
  return List<Map<String, dynamic>>.from(data as List);
}
```

**upsertAnswer pattern** (audit_answer_service.dart lines 23-39):
```dart
Future<void> upsertAnswer({
  required String auditId,
  required String templateItemId,
  required String response,
  String? observation,
}) async {
  await _client.from('audit_answers').upsert(
    {
      'audit_id': auditId,
      'template_item_id': templateItemId,
      'response': response,
      'observation': observation,
      'answered_at': DateTime.now().toIso8601String(),
    },
    onConflict: 'audit_id,template_item_id',
  );
}
```
For checklist: rename params to `executionId`/`itemId`, table to `checklist_answers`, onConflict to `'execution_id,item_id'`.

**calculateConformity static method pattern** (audit_answer_service.dart lines 52-81):
```dart
static double calculateConformity(
  List<TemplateItem> items,
  Map<String, String> answers,
) {
  double totalWeight = 0;
  double earned = 0;

  for (final item in items) {
    totalWeight += item.weight;
    final ans = answers[item.id];
    if (ans == null || ans.isEmpty) continue;

    switch (item.responseType) {
      case 'yes_no':
        if (ans == 'yes') earned += item.weight;
      case 'text':
      case 'selection':
        if (ans.isNotEmpty) earned += item.weight;
    }
  }

  if (totalWeight == 0) return 100.0;
  return (earned / totalWeight * 100).clamp(0.0, 100.0);
}
```
For checklist, no `weight` — replace with simple count. Also filter only conformity-eligible types (`yes_no`, `text`, `multiple_choice`):
```dart
static double calculateConformity(
  List<ChecklistTemplateItem> items,
  Map<String, String> answers,
) {
  const conformityTypes = {'yes_no', 'text', 'multiple_choice'};
  final eligible = items.where((i) => conformityTypes.contains(i.itemType)).toList();
  if (eligible.isEmpty) return 100.0;
  int total = eligible.length;
  int conforming = 0;
  for (final item in eligible) {
    final ans = answers[item.id];
    if (ans == null || ans.isEmpty) continue;
    switch (item.itemType) {
      case 'yes_no':
        if (ans == 'yes') conforming++;
      case 'text':
        if (ans.isNotEmpty) conforming++;
      case 'multiple_choice':
        if (ans.isNotEmpty) conforming++;
    }
  }
  return (conforming / total * 100).clamp(0.0, 100.0);
}
```

---

### `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` (screen, event-driven)

**Analog:** `primeaudit/lib/screens/audit_execution_screen.dart`

**Imports pattern** (audit_execution_screen.dart lines 1-20):
```dart
import 'dart:math' show pow;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../services/audit_answer_service.dart';
import '../services/audit_service.dart';
import '../services/audit_template_service.dart';
import 'pending_save.dart';

typedef _PendingSave = PendingSave;
```
For checklist screen, import `checklist_pending_save.dart` from same directory (new file, same structure as `pending_save.dart`). Remove corrective action imports.

**State fields pattern** (audit_execution_screen.dart lines 32-60):
```dart
class _AuditExecutionScreenState extends State<AuditExecutionScreen> {
  static const int _maxAutoRetryAttempts = 4;

  final _templateService = AuditTemplateService();
  final _answerService = AuditAnswerService();
  final _auditService = AuditService();

  List<TemplateSection> _sections = [];
  List<TemplateItem> _allItems = [];

  final Map<String, String> _answers = {};
  final Map<String, String> _observations = {};
  final Map<String, _PendingSave> _failedSaves = {};
  final Set<String> _retrying = {};

  bool _loading = true;
  bool _finalizing = false;
  String? _error;
```
For checklist: replace `_sections` (no sections) with `List<ChecklistTemplateItem> _allItems = []`. Keep all `_answers`, `_observations`, `_failedSaves`, `_retrying`, `_loading`, `_finalizing`, `_error` unchanged.

**_load pattern with Future.wait** (audit_execution_screen.dart lines 68-148):
```dart
Future<void> _load() async {
  setState(() { _loading = true; _error = null; });
  try {
    final results = await Future.wait([
      _templateService.getSections(templateId),
      _templateService.getItems(templateId),
      _answerService.getAnswers(widget.audit.id),
    ]);
    // populate _answers from results[2]:
    for (final a in answers) {
      final ans = a as dynamic;
      _answers[ans.templateItemId] = ans.response;
      if (ans.observation != null) {
        _observations[ans.templateItemId] = ans.observation!;
      }
    }
    if (mounted) setState(() { _allItems = [...items]; _loading = false; });
  } catch (e) {
    if (mounted) setState(() { _error = '$e'; _loading = false; });
  }
}
```
For checklist: `Future.wait` on `[_templateService.getItems(templateId), _answerService.getAnswers(widget.execution.id)]`. Populate answers via `_answers[row['item_id']] = row['response']`.

**_onAnswer / _onObservation pattern** (audit_execution_screen.dart lines 175-186):
```dart
void _onAnswer(String itemId, String response) {
  if (_isReadOnly) return;
  setState(() => _answers[itemId] = response);
  _saveAnswer(itemId, response);   // fire-and-forget — no await
}

void _onObservation(String itemId, String obs) {
  if (_isReadOnly) return;
  _observations[itemId] = obs;
  final resp = _answers[itemId];
  if (resp != null) _saveAnswer(itemId, resp, observation: obs);
}
```

**_saveAnswer fire-and-forget pattern** (audit_execution_screen.dart lines 272-304):
```dart
Future<void> _saveAnswer(
  String itemId,
  String response, {
  String? observation,
}) async {
  final obs = observation ?? _observations[itemId];
  try {
    await _answerService.upsertAnswer(
      auditId: widget.audit.id,
      templateItemId: itemId,
      response: response,
      observation: obs,
    );
    if (_failedSaves.containsKey(itemId) && mounted) {
      setState(() => _failedSaves.remove(itemId));
    }
  } catch (e) {
    debugPrint('[_saveAnswer] itemId=$itemId erro: $e');
    if (!mounted) return;
    setState(() {
      _failedSaves[itemId] = _PendingSave(
        itemId: itemId,
        response: response,
        observation: obs,
      );
    });
    _showSaveError(itemId, response, obs);
    _scheduleRetry(itemId);
  }
}
```
Copy verbatim, replacing `auditId`/`templateItemId` with `executionId`/`itemId`.

**_showSaveError snackbar pattern** (audit_execution_screen.dart lines 307-329):
```dart
void _showSaveError(String itemId, String response, String? observation) {
  if (!mounted) return;
  final messenger = ScaffoldMessenger.of(context);  // capture BEFORE async gap
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Não foi possível salvar'),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Tentar novamente',
        textColor: Colors.white,
        onPressed: () {
          _saveAnswer(itemId, response, observation: observation);
        },
      ),
    ),
  );
}
```

**_scheduleRetry exponential backoff pattern** (audit_execution_screen.dart lines 335-371):
```dart
Future<void> _scheduleRetry(String itemId) async {
  if (_retrying.contains(itemId)) return;
  _retrying.add(itemId);
  try {
    while (_failedSaves.containsKey(itemId)) {
      final pending = _failedSaves[itemId]!;
      if (pending.attemptCount >= _maxAutoRetryAttempts) break;

      final delaySeconds = pow(2, pending.attemptCount).toInt(); // 1, 2, 4, 8
      await Future.delayed(Duration(seconds: delaySeconds));

      if (!mounted || !_failedSaves.containsKey(itemId)) break;

      try {
        await _answerService.upsertAnswer(...);
        if (mounted) setState(() => _failedSaves.remove(itemId));
        break;
      } catch (_) {
        if (mounted) setState(() {
          _failedSaves[itemId] = pending.copyWithAttempt();
        });
      }
    }
  } finally {
    _retrying.remove(itemId);
  }
}
```
Copy verbatim with `executionId`/`itemId` substitution.

**_finalize guard pattern** (audit_execution_screen.dart lines 415-438):
```dart
Future<void> _finalize() async {
  if (_failedSaves.isNotEmpty) {
    final count = _failedSaves.length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respostas não salvas'),
        content: Text('$count resposta(s) não salva(s). Resolva as falhas antes de finalizar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return;
  }
  // ... confirmation dialog + service.finalizeExecution(id, conformity)
```

**build / _buildAppBar with progress bar pattern** (audit_execution_screen.dart lines 548-636):
```dart
@override
Widget build(BuildContext context) {
  final t = AppTheme.of(context);
  return Scaffold(
    backgroundColor: t.background,
    appBar: _buildAppBar(t),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
            ? _buildError(t)
            : _buildBody(t),
    bottomNavigationBar: (!_loading && _error == null) ? _buildBottomBar(t) : null,
  );
}
```
AppBar bottom progress bar (lines 607-635) — copy for checklist with `_answeredItems / _totalItems` counters.

**_buildBottomBar conformity + finalize button pattern** (audit_execution_screen.dart lines 806-862):
```dart
return Container(
  decoration: BoxDecoration(
    color: t.surface,
    border: Border(top: BorderSide(color: t.divider)),
  ),
  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
  child: Row(
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Conformidade', style: TextStyle(fontSize: 11, color: t.textSecondary)),
          Text(
            '${_conformity.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: _conformityColor(_conformity)),
          ),
        ],
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton(
          onPressed: !_finalizing ? _finalize : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _finalizing
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Finalizar checklist',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ),
    ],
  ),
);
```
For checklist: remove `_canFinalize` guard (no required items). Button is always enabled when `!_finalizing`.

**_conformityColor static helper** (audit_execution_screen.dart lines 864-868):
```dart
static Color _conformityColor(double pct) {
  if (pct >= 80) return const Color(0xFF43A047);
  if (pct >= 60) return const Color(0xFFFFA000);
  return AppColors.error;
}
```
Copy verbatim.

**_buildError with retry button pattern** (audit_execution_screen.dart lines 638-659):
```dart
Widget _buildError(AppTheme t) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: t.textSecondary),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
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
```

**_AnswerWidget switch pattern** (audit_execution_screen.dart lines 1323-1394):
```dart
class _AnswerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    switch (item.responseType) {
      case 'yes_no':
        return _TwoOptionButtons(
          options: const [
            _OptionDef('yes', 'Sim', Icons.thumb_up_rounded,   Color(0xFF43A047)),
            _OptionDef('no',  'Não', Icons.thumb_down_rounded, AppColors.error),
          ],
          selected: answer, readOnly: readOnly, onSelect: onAnswer, theme: theme,
        );
      case 'text':
        return _TextAnswer(initial: answer, readOnly: readOnly,
            onChanged: onAnswer, theme: theme);
      case 'selection':
        return _SelectionAnswer(options: item.options, selected: answer,
            readOnly: readOnly, onSelect: onAnswer, theme: theme);
      default:
        return const SizedBox.shrink();
    }
  }
}
```
For checklist switch on `item.itemType` adding `'number'`, `'date'`, `'multiple_choice'`, `'photo'` cases.

**_TwoOptionButtons — copy verbatim** (audit_execution_screen.dart lines 1406-1463) — identical widget for `yes_no` in checklist.

**_TextAnswer — copy verbatim** (audit_execution_screen.dart lines 1600-1651) — identical `StatefulWidget` with `TextEditingController` and `dispose()`.

**_SelectionAnswer — reuse as _MultipleChoiceAnswer** (audit_execution_screen.dart lines 1654-1702):
```dart
class _SelectionAnswer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text('Nenhuma opção configurada.',
          style: TextStyle(color: t.textSecondary, fontSize: 12));
    }
    return Wrap(
      spacing: 8, runSpacing: 6,
      children: options.map((opt) {
        final sel = selected == opt;
        return GestureDetector(
          onTap: readOnly ? null : () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary.withValues(alpha: 0.1) : t.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? AppColors.primary : t.divider,
                  width: sel ? 1.5 : 1),
            ),
            child: Text(opt, style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              color: sel ? AppColors.primary : t.textPrimary,
            )),
          ),
        );
      }).toList(),
    );
  }
}
```
Copy as `_MultipleChoiceAnswer` using `item.options` instead of `item.options` (same field name after ChecklistTemplateItem modification).

**_ItemCard pattern** (audit_execution_screen.dart lines 1007-1263) — Rename to `_ChecklistItemCard`. Key differences from audit version:
- No `item.required` guard — no `_Badge('Obrigatório')` badge
- No `item.guidance` colapsável — checklist items have no guidance field
- No corrective action section
- Observation text field — copy verbatim (lines 1225-1257)
- Item number badge — copy verbatim (lines 1089-1112)

**_Badge widget — copy verbatim** (audit_execution_screen.dart lines 1704-1723):
```dart
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
```

**showModalBottomSheet for _StartChecklistSheet** — from `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart` (lines 126-140):
```dart
Future<void> _showStartSheet(ChecklistTemplate t) async {
  final created = await showModalBottomSheet<ChecklistExecution>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _StartChecklistSheet(
      template: t,
      service: _executionService,
      parentContext: context,
    ),
  );
  if (created != null && mounted) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChecklistExecutionScreen(execution: created),
    )).then((_) => _load());
  }
}
```

**mounted + messenger capture before async — pattern** from checklist_template_list_screen.dart (lines 473-486):
```dart
final messenger = ScaffoldMessenger.of(widget.parentContext);  // before async gap
// ... await ...
if (mounted) Navigator.pop(context);
```

---

### `primeaudit/lib/screens/checklist/checklist_pending_save.dart` (utility, event-driven)

**Analog:** `primeaudit/lib/screens/pending_save.dart` (full file, 27 lines)

Copy the entire file verbatim, changing class name `PendingSave` → `ChecklistPendingSave`:
```dart
class ChecklistPendingSave {
  final String itemId;
  final String response;
  final String? observation;
  final int attemptCount;

  const ChecklistPendingSave({
    required this.itemId,
    required this.response,
    this.observation,
    this.attemptCount = 0,
  });

  ChecklistPendingSave copyWithAttempt() => ChecklistPendingSave(
        itemId: itemId,
        response: response,
        observation: observation,
        attemptCount: attemptCount + 1,
      );
}
```
In `checklist_execution_screen.dart`, alias with: `typedef _PendingSave = ChecklistPendingSave;` (same pattern as audit_execution_screen.dart line 20).

---

## Shared Patterns

### Auth-aware userId retrieval
**Source:** `primeaudit/lib/services/audit_service.dart` (createAudit, inferred from `auditor_id`)
**Apply to:** `ChecklistExecutionService.createExecution`
```dart
final userId = _client.auth.currentUser!.id;
```

### Error Handling — try/catch with setState
**Source:** `primeaudit/lib/screens/audit_execution_screen.dart` lines 146-148
**Apply to:** All async methods in `ChecklistExecutionScreen`
```dart
} catch (e) {
  if (mounted) setState(() { _error = '$e'; _loading = false; });
}
```

### Error Handling — snackbar floating
**Source:** `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart` lines 104-110
**Apply to:** All user-facing errors in `ChecklistExecutionScreen` and `_StartChecklistSheet`
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Erro ao ...'),
    backgroundColor: AppColors.error,
    behavior: SnackBarBehavior.floating,
  ),
);
```

### mounted guard before context use post-await
**Source:** `primeaudit/lib/screens/audit_execution_screen.dart` line 293
**Apply to:** Every async method in `ChecklistExecutionScreen` that uses `context` after any `await`
```dart
if (!mounted) return;
// only then use context
```

### CompanyContext for company_id
**Source:** `primeaudit/lib/screens/audit_execution_screen.dart` (pattern from home_screen.dart _NewAuditSheet)
**Apply to:** `_StartChecklistSheet.onConfirm` → `createExecution`
```dart
final companyId = CompanyContextService.instance.activeCompanyId;
```

### AppTheme token lookup
**Source:** `primeaudit/lib/screens/audit_execution_screen.dart` line 550
**Apply to:** Every `build` method in new widgets
```dart
final t = AppTheme.of(context);
// then use t.background, t.surface, t.textPrimary, t.textSecondary, t.divider
```

### Navigator push returning value for list refresh
**Source:** `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart` lines 67-71
**Apply to:** Navigation from `ChecklistTemplateListScreen` to `ChecklistExecutionScreen`
```dart
Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => ChecklistExecutionScreen(...)))
    .then((_) => _load());
```

### Date-only serialization — no intl dependency
**Source:** `primeaudit/lib/models/audit.dart` lines 115-121 (pitfall documented)
**Apply to:** `createExecution` date serialization and `ChecklistExecution.fromMap` date parsing
```dart
// Serialize: no timezone
final dateStr = dataExecucao.toIso8601String().substring(0, 10); // 'yyyy-MM-dd'

// Parse: treat as date-only (no toLocal())
dataExecucao: DateTime.parse(map['data_execucao']),
```

---

## No Analog Found

All files have close analogs. No entry required here.

---

## New Widgets — No Analog (implement from scratch per RESEARCH.md)

| Widget | Role | Notes |
|---|---|---|
| `_NumberAnswer` | answer widget | `TextField` with `keyboardType: TextInputType.numberWithOptions(decimal: true)` + `FilteringTextInputFormatter`. Standard Flutter — no analog in codebase. |
| `_DateAnswer` | answer widget | `OutlinedButton.icon` that triggers `showDatePicker()`. Standard Flutter Material — no analog in codebase. |

Both are `StatefulWidget` following the same structure as `_TextAnswer` (audit_execution_screen.dart lines 1600-1651): `late final TextEditingController _ctrl`, `dispose()` override, `initState()`.

---

## Metadata

**Analog search scope:** `primeaudit/lib/models/`, `primeaudit/lib/services/`, `primeaudit/lib/screens/`, `primeaudit/supabase/migrations/`
**Files scanned:** 8 source files read directly
**Pattern extraction date:** 2026-05-05
