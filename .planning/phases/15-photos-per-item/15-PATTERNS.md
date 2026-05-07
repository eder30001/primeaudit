# Phase 15: Photos per Item — Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 4 (3 new, 1 modified)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/lib/models/checklist_item_image.dart` | model | CRUD | `primeaudit/lib/models/audit_item_image.dart` | exact |
| `primeaudit/lib/services/checklist_image_service.dart` | service | file-I/O + CRUD | `primeaudit/lib/services/image_service.dart` | exact |
| `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql` | migration | — | `primeaudit/supabase/migrations/20260428_create_audit_item_images.sql` | exact |
| `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` | screen | request-response + file-I/O | `primeaudit/lib/screens/create_corrective_action_screen.dart` | exact (photo strip pattern) |

---

## Pattern Assignments

### `primeaudit/lib/models/checklist_item_image.dart` (model, CRUD)

**Analog:** `primeaudit/lib/models/audit_item_image.dart`
**Match:** Structural mirror — same field set, rename `auditId → executionId`, `templateItemId → itemId`, drop `correctiveActionId`.

**Full analog** (lines 1–40 of `audit_item_image.dart`):
```dart
class AuditItemImage {
  final String id;
  final String auditId;
  final String templateItemId;
  final String companyId;
  final String storagePath;
  final String createdBy;
  final DateTime createdAt;
  final String? correctiveActionId;

  const AuditItemImage({
    required this.id,
    required this.auditId,
    required this.templateItemId,
    required this.companyId,
    required this.storagePath,
    required this.createdBy,
    required this.createdAt,
    this.correctiveActionId,
  });

  factory AuditItemImage.fromMap(Map<String, dynamic> map) {
    return AuditItemImage(
      id: map['id'] as String,
      auditId: map['audit_id'] as String,
      templateItemId: map['template_item_id'] as String,
      companyId: map['company_id'] as String,
      storagePath: map['storage_path'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      correctiveActionId: map['corrective_action_id'] as String?,
    );
  }
}
```

**Rename map for `ChecklistItemImage`:**

| `AuditItemImage` field | `ChecklistItemImage` field | DB column |
|------------------------|---------------------------|-----------|
| `auditId` | `executionId` | `execution_id` |
| `templateItemId` | `itemId` | `item_id` |
| `correctiveActionId` (optional) | _drop_ | — |

**No imports needed** — model is pure Dart, no `dart:` or package imports.

---

### `primeaudit/lib/services/checklist_image_service.dart` (service, file-I/O + CRUD)

**Analog:** `primeaudit/lib/services/image_service.dart`

**Imports pattern** (lines 1–4 of `image_service.dart`):
```dart
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_item_image.dart';
```
Change last import to: `import '../models/checklist_item_image.dart';`

**Client + bucket declaration** (lines 13–15 of `image_service.dart`):
```dart
class ImageService {
  final _client = Supabase.instance.client;
  static const _bucket = 'audit-images';
```
Change class name to `ChecklistImageService`, bucket to `'checklist-images'`.

**UUID generator pattern** (lines 18–30 of `image_service.dart` — copy verbatim):
```dart
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
```

**uploadImage pattern** (lines 38–64 of `image_service.dart`):
```dart
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
```
**Rename map for `ChecklistImageService.uploadImage`:**
- Signature: `auditId → executionId`
- `path`: `'$companyId/$executionId/$itemId/$uuid.jpg'`
- Table: `'checklist_item_images'`
- Insert keys: `'execution_id': executionId`, `'item_id': itemId` (drop `template_item_id`, `audit_id`)
- Return type: `ChecklistItemImage.fromMap(row)`

**getImages pattern** (lines 66–82 of `image_service.dart`):
```dart
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
```
**Add `getImagesByExecution` (new method not in analog):**
```dart
Future<List<ChecklistItemImage>> getImagesByExecution(String executionId) async {
  final rows = await _client
      .from('checklist_item_images')
      .select()
      .eq('execution_id', executionId)
      .order('created_at');
  return (rows as List).map((r) => ChecklistItemImage.fromMap(r)).toList();
}
```
This replaces the N-query per-item approach with a single query for `_load()`.

**getSignedUrl pattern** (lines 94–99 of `image_service.dart` — copy verbatim):
```dart
Future<String> getSignedUrl(String storagePath) async {
  return await _client.storage
      .from(_bucket)
      .createSignedUrl(storagePath, 3600);
}
```

**deleteImage pattern** (lines 101–116 of `image_service.dart` — copy verbatim):
```dart
Future<void> deleteImage({
  required String imageId,
  required String storagePath,
}) async {
  try {
    await _client.storage.from(_bucket).remove([storagePath]);
  } catch (_) {
    // Storage delete falhou — continua para remover o registro da tabela
  }
  await _client.from('checklist_item_images').delete().eq('id', imageId);
}
```
Change table name to `'checklist_item_images'`. Drop `linkImagesToAction` — not needed in Phase 15.

---

### `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql` (migration)

**Analog:** `primeaudit/supabase/migrations/20260428_create_audit_item_images.sql`

**Section 1 — Table structure** (lines 7–18 of analog — copy structure, rename):
```sql
CREATE TABLE IF NOT EXISTS audit_item_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS audit_id          UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS template_item_id  UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS company_id        UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS storage_path      TEXT NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS created_by        UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW();
```
**Rename map:**
- Table: `checklist_item_images`
- Column `audit_id` → `execution_id` (references `checklist_executions(id) ON DELETE CASCADE`)
- Column `template_item_id` → `item_id` (references `checklist_template_items(id) ON DELETE CASCADE`)
- Drop: no `corrective_action_id` column

**Section 2 — FK pattern** (lines 21–35 of analog):
```sql
ALTER TABLE audit_item_images DROP CONSTRAINT IF EXISTS audit_item_images_audit_id_fkey;
ALTER TABLE audit_item_images ADD CONSTRAINT audit_item_images_audit_id_fkey
  FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE;
```
Apply same DROP+ADD pattern for `checklist_item_images`:
- `execution_id → checklist_executions(id) ON DELETE CASCADE`
- `item_id → checklist_template_items(id) ON DELETE CASCADE`
- `company_id → companies(id) ON DELETE RESTRICT`
- `created_by → profiles(id) ON DELETE RESTRICT`

**Section 3 — Indexes** (lines 37–43 of analog):
```sql
CREATE INDEX IF NOT EXISTS idx_audit_item_images_audit_item
  ON audit_item_images (audit_id, template_item_id);
CREATE INDEX IF NOT EXISTS idx_audit_item_images_company_id
  ON audit_item_images (company_id);
CREATE INDEX IF NOT EXISTS idx_audit_item_images_created_at
  ON audit_item_images (created_at DESC);
```
Rename to `idx_checklist_item_images_*` with columns `(execution_id, item_id)`, `(company_id)`, `(created_at DESC)`.

**Section 4 — RLS for table** (lines 45–84 of analog):
```sql
ALTER TABLE audit_item_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_audit_item_images_full" ON audit_item_images;
CREATE POLICY "superuser_dev_audit_item_images_full" ON audit_item_images
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

DROP POLICY IF EXISTS "adm_audit_item_images_company" ON audit_item_images;
CREATE POLICY "adm_audit_item_images_company" ON audit_item_images
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());
```
The analog uses Pattern 2 (company_id) for auditor SELECT/INSERT/DELETE. For `checklist_item_images`, the RESEARCH.md requires **Pattern 3** (EXISTS subquery via `checklist_executions`) for auditor policies — tighter than the audit analog. Use Pattern 2 only for `adm`. Full auditor policies from RESEARCH.md section 1.2.

**Section 5 — Bucket + Storage RLS** (lines 86–127 of analog — copy verbatim, substituting names):
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('audit-images', 'audit-images', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "authenticated_upload_audit_images" ON storage.objects;
CREATE POLICY "authenticated_upload_audit_images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'audit-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );
```
Substitute: bucket `'checklist-images'`, policy names `authenticated_*_checklist_images`.

**Final line** (line 127 of analog — always last):
```sql
NOTIFY pgrst, 'reload schema';
```

---

### `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` (screen, modifications)

**Analog for photo strip:** `primeaudit/lib/screens/create_corrective_action_screen.dart`
**File being modified:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart`

#### Modification 1 — New imports (add to existing import block at lines 1–11)

From analog lines 1–14:
```dart
import 'dart:io';                                      // required for Image.file
import 'package:image_picker/image_picker.dart';
import '../../models/checklist_item_image.dart';
import '../../services/checklist_image_service.dart';
import '../../services/company_context_service.dart';
```
Note: `dart:math` is already imported at line 1 as `dart:math show pow` — leave as-is. Do NOT add `dart:math` again.

#### Modification 2 — New state fields (add to `_ChecklistExecutionScreenState`, after line 47)

```dart
// Photos per item — Map: itemId → list of photo entries with upload state
final _imageService = ChecklistImageService();
final Map<String, List<_ChecklistPhotoEntry>> _photosPerItem = {};
```

#### Modification 3 — Extend `_load()` (lines 61–106 of checklist_execution_screen.dart)

Current `Future.wait` at line 70:
```dart
final results = await Future.wait([
  _templateService.getItems(templateId),
  _answerService.getAnswers(widget.execution.id),
]);
```
Extend to:
```dart
final results = await Future.wait([
  _templateService.getItems(templateId),
  _answerService.getAnswers(widget.execution.id),
  _imageService.getImagesByExecution(widget.execution.id),
]);
```
After unpacking results, group images into `_photosPerItem`. Use `Future.wait` for parallel signed URL generation (Pitfall 3 from RESEARCH.md):
```dart
final imageRows = results[2] as List<ChecklistItemImage>;

// Generate signed URLs in parallel — avoid sequential N round-trips
final urls = await Future.wait(
  imageRows.map((img) => _imageService
      .getSignedUrl(img.storagePath)
      .catchError((_) => '')),
);

final photosMap = <String, List<_ChecklistPhotoEntry>>{};
for (var idx = 0; idx < imageRows.length; idx++) {
  final img = imageRows[idx];
  final url = urls[idx].isEmpty ? null : urls[idx];
  final entry = _ChecklistPhotoEntry(
    key: img.id,
    state: url != null ? _ChecklistPhotoState.uploaded : _ChecklistPhotoState.error,
    image: img,
    signedUrl: url,
  );
  photosMap.putIfAbsent(img.itemId, () => []).add(entry);
}

if (mounted) {
  setState(() {
    // Merge: preserve uploading/error entries not yet in DB over DB data
    for (final entry in photosMap.entries) {
      _photosPerItem[entry.key] = entry.value;
    }
    // ...existing _answers / _observations merge logic...
  });
}
```

#### Modification 4 — `_pickPhoto` method (new — add to `_ChecklistExecutionScreenState`)

Copy from `create_corrective_action_screen.dart` lines 143–182, adapting for per-item Map state:
```dart
Future<void> _pickPhoto(String itemId) async {
  final messenger = ScaffoldMessenger.of(context); // BEFORE any await
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
  setState(() {
    _photosPerItem.putIfAbsent(itemId, () => []).add(
      _ChecklistPhotoEntry(key: key, state: _ChecklistPhotoState.uploading, file: file),
    );
  });

  try {
    final companyId = CompanyContextService.instance.activeCompanyId!;
    final img = await _imageService.uploadImage(
      companyId: companyId,
      executionId: widget.execution.id,
      itemId: itemId,
      file: file,
    );
    final url = await _imageService.getSignedUrl(img.storagePath);
    if (!mounted) return;
    setState(() {
      final photos = _photosPerItem[itemId]!;
      final i = photos.indexWhere((p) => p.key == key);
      if (i >= 0) photos[i] = photos[i].copyWith(
        state: _ChecklistPhotoState.uploaded, image: img, signedUrl: url);
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      final photos = _photosPerItem[itemId]!;
      final i = photos.indexWhere((p) => p.key == key);
      if (i >= 0) photos[i] = photos[i].copyWith(state: _ChecklistPhotoState.error);
    });
    messenger.showSnackBar(
      SnackBar(content: Text('Upload falhou: $e'), behavior: SnackBarBehavior.floating),
    );
  }
}
```

#### Modification 5 — `_retryPhoto` and `_removePhoto` methods (new)

Copy `_retryPhoto` from analog lines 184–212, adapting for Map state:
```dart
Future<void> _retryPhoto(String itemId, String key) async {
  final photos = _photosPerItem[itemId];
  if (photos == null) return;
  final entry = photos.firstWhere((p) => p.key == key);
  if (entry.file == null) return;
  setState(() {
    final i = photos.indexWhere((p) => p.key == key);
    if (i >= 0) photos[i] = photos[i].copyWith(state: _ChecklistPhotoState.uploading);
  });
  try {
    final companyId = CompanyContextService.instance.activeCompanyId!;
    final img = await _imageService.uploadImage(
      companyId: companyId,
      executionId: widget.execution.id,
      itemId: itemId,
      file: entry.file!,
    );
    final url = await _imageService.getSignedUrl(img.storagePath);
    if (!mounted) return;
    setState(() {
      final i = photos.indexWhere((p) => p.key == key);
      if (i >= 0) photos[i] = photos[i].copyWith(
          state: _ChecklistPhotoState.uploaded, image: img, signedUrl: url);
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      final i = photos.indexWhere((p) => p.key == key);
      if (i >= 0) photos[i] = photos[i].copyWith(state: _ChecklistPhotoState.error);
    });
  }
}

Future<void> _removePhoto(String itemId, String key) async {
  final photos = _photosPerItem[itemId];
  if (photos == null) return;
  final entry = photos.firstWhere((p) => p.key == key);
  setState(() => photos.removeWhere((p) => p.key == key));
  if (entry.image != null) {
    try {
      await _imageService.deleteImage(
          imageId: entry.image!.id, storagePath: entry.image!.storagePath);
    } catch (_) {}
  }
}
```

#### Modification 6 — Extend `_ChecklistItemCard` (lines 526–545)

Add optional photo props to the existing constructor:
```dart
// New fields to add to _ChecklistItemCard:
final List<_ChecklistPhotoEntry>? photos;
final void Function(String itemId)? onPickPhoto;
final void Function(String itemId, String key)? onRetryPhoto;
final void Function(String itemId, String key)? onRemovePhoto;
```
In the `ListView.builder` at lines 443–454, pass them:
```dart
return _ChecklistItemCard(
  item: item,
  itemNumber: i + 1,
  answer: _answers[item.id],
  observation: _observations[item.id],
  readOnly: _finalizing,
  onAnswer: (r) => _onAnswer(item.id, r),
  onObservation: (o) => _onObservation(item.id, o),
  theme: t,
  // New in Phase 15:
  photos: item.itemType == 'photo' ? (_photosPerItem[item.id] ?? []) : null,
  onPickPhoto: _pickPhoto,
  onRetryPhoto: _retryPhoto,
  onRemovePhoto: _removePhoto,
);
```
In `_ChecklistItemCardState.build()`, after the `_AnswerWidget` block (after line 652), add the strip conditionally:
```dart
// After existing _AnswerWidget(...)
if (widget.item.itemType == 'photo' && widget.photos != null)
  Padding(
    padding: const EdgeInsets.only(top: 12),
    child: _ChecklistPhotoStrip(
      itemId: widget.item.id,
      photos: widget.photos!,
      readOnly: widget.readOnly,
      onPickPhoto: widget.onPickPhoto!,
      onRetryPhoto: widget.onRetryPhoto!,
      onRemovePhoto: widget.onRemovePhoto!,
      theme: widget.theme,
    ),
  ),
```

#### Modification 7 — Replace `_PhotoPlaceholder` switch case (line 794–795)

```dart
// BEFORE (line 794–795):
case 'photo':
  return _PhotoPlaceholder(theme: theme);

// AFTER: strip is injected by _ChecklistItemCard directly above _AnswerWidget
// The 'photo' case in _AnswerWidget can return SizedBox.shrink() since the
// strip is rendered by the parent card, not the answer widget.
case 'photo':
  return const SizedBox.shrink();
```
The `_PhotoPlaceholder` class (lines 1122–1148) can be removed entirely.

#### New types added at bottom of file (after existing closing braces)

**Enum and entry class** — copy from analog lines 512–541, rename:
```dart
// _PhotoState (analog) lines 512-512
enum _ChecklistPhotoState { uploading, uploaded, error }

// _PhotoEntry (analog) lines 514-541
class _ChecklistPhotoEntry {
  final String key;
  final _ChecklistPhotoState state;
  final XFile? file;
  final ChecklistItemImage? image;
  final String? signedUrl;

  const _ChecklistPhotoEntry({
    required this.key,
    required this.state,
    this.file,
    this.image,
    this.signedUrl,
  });

  _ChecklistPhotoEntry copyWith({
    _ChecklistPhotoState? state,
    ChecklistItemImage? image,
    String? signedUrl,
  }) =>
      _ChecklistPhotoEntry(
        key: key,
        state: state ?? this.state,
        file: file,
        image: image ?? this.image,
        signedUrl: signedUrl ?? this.signedUrl,
      );
}
```

**`_PhotoSourceSheet`** — copy verbatim from analog lines 546–571 (identical, no rename needed).

**`_ChecklistPhotoStrip`** — new `StatelessWidget`, mirrors `_buildPhotoSection` + `_buildThumb` from analog (lines 260–361) but as a separate widget receiving props:
```dart
class _ChecklistPhotoStrip extends StatelessWidget {
  final String itemId;
  final List<_ChecklistPhotoEntry> photos;
  final bool readOnly;
  final void Function(String itemId) onPickPhoto;
  final void Function(String itemId, String key) onRetryPhoto;
  final void Function(String itemId, String key) onRemovePhoto;
  final AppTheme theme;

  const _ChecklistPhotoStrip({
    required this.itemId,
    required this.photos,
    required this.readOnly,
    required this.onPickPhoto,
    required this.onRetryPhoto,
    required this.onRemovePhoto,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) { /* Row with camera button + horizontal scroll strip */ }

  Widget _buildThumb(_ChecklistPhotoEntry p) { /* copy _buildThumb from analog lines 307–361 */ }
}
```

---

## Shared Patterns

### Mounted guard after async
**Source:** `primeaudit/lib/screens/create_corrective_action_screen.dart` line 169
**Source (existing):** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` line 161
**Apply to:** `_pickPhoto`, `_retryPhoto`, `_removePhoto`
```dart
if (!mounted) return;
```
After every `await` that is followed by `setState` or `context` usage.

### ScaffoldMessenger captured before await
**Source:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` lines 175–177
```dart
// Pitfall 1: captura o messenger ANTES de qualquer async gap
void _showSaveError(...) {
  if (!mounted) return;
  final messenger = ScaffoldMessenger.of(context); // ANTES de qualquer await
```
**Apply to:** `_pickPhoto` — capture `messenger` as first statement before any `await`.

### Fire-and-forget + isolation from `_failedSaves`
**Source:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` lines 127–171
```dart
void _onAnswer(String itemId, String response) {
  if (_finalizing) return;
  setState(() => _answers[itemId] = response);
  _saveAnswer(itemId, response); // fire-and-forget — sem await
}
```
**Apply to:** Photo operations are fully parallel to `_saveAnswer` — `_pickPhoto` is never called from `_onAnswer`, never touches `_failedSaves`, and `_finalize` never checks photo state.

### SnackBar floating style
**Source:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` line 179
```dart
SnackBar(
  content: ...,
  behavior: SnackBarBehavior.floating,
  ...
)
```
**Apply to:** Error snackbar in `_pickPhoto` catch block.

### Idempotent migration structure
**Source:** `primeaudit/supabase/migrations/20260428_create_audit_item_images.sql` lines 1–127
- `CREATE TABLE IF NOT EXISTS` for base table
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` for each column
- `DROP CONSTRAINT IF EXISTS` then `ADD CONSTRAINT` for FKs (idempotent)
- `CREATE INDEX IF NOT EXISTS` for indexes
- `DROP POLICY IF EXISTS` then `CREATE POLICY` for RLS (idempotent)
- `INSERT INTO storage.buckets ... ON CONFLICT (id) DO NOTHING` for bucket
- `NOTIFY pgrst, 'reload schema';` as last line

**Apply to:** `20260510_create_checklist_item_images.sql` — every section must follow this pattern.

---

## No Analog Found

All 4 files have exact analogs. No files require fallback to RESEARCH.md patterns only.

---

## Key Differences from Analogs (Summary)

| Aspect | Audit analog | Checklist Phase 15 |
|--------|--------------|--------------------|
| Scope key | `audit_id` / `template_item_id` | `execution_id` / `item_id` |
| Bucket | `audit-images` | `checklist-images` |
| Table | `audit_item_images` | `checklist_item_images` |
| FK reference | `audits(id)` / `template_items(id)` | `checklist_executions(id)` / `checklist_template_items(id)` |
| Corrective action link | `correctiveActionId` + `linkImagesToAction` | Not present |
| Auditor RLS pattern | Pattern 2 (company_id) | Pattern 3 (EXISTS subquery via execution FK) |
| Photo state in screen | `List<_PhotoEntry> _photos` (flat) | `Map<String, List<_ChecklistPhotoEntry>> _photosPerItem` (per item) |
| Strip widget | Inline `_buildPhotoSection` in screen | `_ChecklistPhotoStrip` StatelessWidget with callbacks |
| Images load in `_load()` | Not applicable (form screen) | `getImagesByExecution()` in `Future.wait` + parallel `getSignedUrl` |

---

## Metadata

**Analog search scope:** `primeaudit/lib/models/`, `primeaudit/lib/services/`, `primeaudit/lib/screens/`, `primeaudit/supabase/migrations/`
**Files scanned:** 5 (4 analogs + 1 target screen)
**Pattern extraction date:** 2026-05-07
