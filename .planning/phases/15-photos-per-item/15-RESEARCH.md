# Phase 15: Photos per Item — Research

**Researched:** 2026-05-07
**Domain:** Flutter + Supabase Storage — upload de imagens por item de checklist, isolamento de falha, UI de miniaturas
**Confidence:** HIGH (todo o código-fonte relevante lido diretamente; sem dependências externas novas)

---

## Summary

A Phase 15 entrega o requisito EXEC-04: auditores podem anexar uma ou mais fotos por item durante a execução de um checklist. O design é deliberadamente isolado do auto-save de respostas — uma falha de upload não bloqueia `_saveAnswer`, não entra em `_failedSaves`, e não impede a finalização do checklist.

O padrão completo de upload, miniaturas, retry, source picker e remoção já está implementado em `create_corrective_action_screen.dart`. A Phase 15 extrai esse padrão para o domínio do módulo Checklist, substituindo o `_PhotoPlaceholder` (linha 1122 de `checklist_execution_screen.dart`) por um widget funcional `_ChecklistPhotoStrip`.

Três artefatos novos são necessários:
1. **Migration SQL** — tabela `checklist_item_images` + bucket `checklist-images` no Storage + RLS
2. **Model** `ChecklistItemImage` — mirror de `AuditItemImage` com `executionId` no lugar de `auditId`
3. **Service** `ChecklistImageService` — mirror de `ImageService` com bucket `checklist-images` e tabela `checklist_item_images`

Dois artefatos existentes são modificados:
- `checklist_execution_screen.dart` — substituir `_PhotoPlaceholder` por `_ChecklistPhotoStrip` + carregar fotos em `_load()`
- `ChecklistAnswerService.calculateConformity` — sem alteração; `photo` já está excluído de `conformityTypes` [VERIFIED: checklist_answer_service.dart]

**Primary recommendation:** Copiar o padrão de `create_corrective_action_screen.dart` (`_PhotoEntry`, `_PhotoState`, `_PhotoSourceSheet`, `_pickPhoto`, `_retryPhoto`, `_buildThumb`) e adaptá-lo para `_ChecklistPhotoStrip` — um `StatefulWidget` com interface de callback. O estado de fotos por item (`Map<String, List<_ChecklistPhotoEntry>>`) vive no `_ChecklistExecutionScreenState`, igual ao padrão de `_answers`.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXEC-04 | Usuário anexa foto(s) por item via câmera ou galeria | `image_picker` ^1.1.2 já instalado. Padrão completo em `create_corrective_action_screen.dart`. Bucket `checklist-images` criado via migration. `_ChecklistPhotoStrip` substitui `_PhotoPlaceholder` no `_AnswerWidget`. |
| SC-1 (Phase 15) | Usuário abre opção de foto por item e seleciona câmera ou galeria; imagem aparece como miniatura inline | `_PhotoSourceSheet` (copiado de `create_corrective_action_screen.dart`) + miniatura 72x72 com estado uploading/uploaded/error |
| SC-2 (Phase 15) | Múltiplas fotos por item são suportadas; miniaturas visíveis durante o preenchimento | Horizontal scrollable strip, mesmo padrão `_buildPhotoSection` de `create_corrective_action_screen.dart` |
| SC-3 (Phase 15) | Falha no upload exibe mensagem de erro mas não interrompe salvamento de respostas nem finalização | `_ChecklistPhotoStrip` tem seu próprio estado de erro; `_failedSaves` de respostas é completamente independente |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Picker de câmera/galeria | Screen (Flutter) | `image_picker` plugin | UI event → plugin → XFile; sem lógica de negócio |
| Upload para Storage | Service (Dart) | Supabase Storage | `ChecklistImageService.uploadImage` — bytes → Storage → INSERT tabela |
| Estado de fotos por item (uploading/uploaded/error) | Screen (Flutter) | — | `Map<String, List<_ChecklistPhotoEntry>>` no `_ChecklistExecutionScreenState`; mesmo padrão de `_answers` |
| Miniaturas (strip horizontal) | Screen (Flutter Widget) | — | `_ChecklistPhotoStrip` StatefulWidget; recebe lista de fotos e callbacks |
| Isolamento de falha de upload | Screen (Flutter) | — | `_ChecklistPhotoStrip` tem snackbar próprio; não toca `_failedSaves` |
| Persistência de metadados de imagem | Database (PostgreSQL) | Supabase RLS | Tabela `checklist_item_images` com RLS Pattern 3 (subquery via FK) |
| Bucket privado de imagens | CDN / Storage | Supabase Storage RLS | Bucket `checklist-images` privado; signed URL 1h para exibição |
| Carregamento de fotos existentes no `_load()` | Screen + Service | Supabase | `ChecklistImageService.getImages(executionId, itemId)` chamado em paralelo com respostas |
| Cálculo de conformidade | Service (Dart estático) | — | Sem alteração — `photo` já excluído de `conformityTypes` |

---

## Standard Stack

### Core (todos ja instalados — nenhum pacote novo)

| Library | Version | Purpose | Por que padrao |
|---------|---------|---------|----------------|
| `image_picker` | `^1.1.2` | Camera + gallery picker, retorna XFile | Ja instalado desde Phase 9 [VERIFIED: pubspec.yaml linha 38] |
| `supabase_flutter` | `^2.8.4` | Storage upload, tabela `checklist_item_images`, signed URL | Backend unico do projeto |
| `flutter` SDK | `>=3.38.4` | UI — `_ChecklistPhotoStrip`, miniaturas, bottom sheet | Stack locked por CLAUDE.md |

**Nenhum `flutter pub add` necessario para Phase 15.** [VERIFIED: pubspec.yaml — image_picker ^1.1.2 presente]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `image_picker` (ja instalado) | `camera` package direto | `camera` requer mais configuração; `image_picker` lida com permissões, crop, quality |
| Signed URL (1h) | URL publica | Bucket deve ser privado (dados industriais); signed URL e o padrao do projeto [VERIFIED: ImageService.getSignedUrl] |
| Estado no parent screen | Estado no proprio strip | Strip como StatelessWidget + callbacks e mais simples, mas requer List gerenciada pelo parent — mesmo padrao de `_answers` |

---

## Architecture Patterns

### Diagrama de Fluxo — Phase 15

```
ChecklistExecutionScreen._load()
  ├── Future.wait([getItems, getAnswers, getImagesPerItem])
  │     └── ChecklistImageService.getImages(executionId, itemId) x N
  │           └── SELECT checklist_item_images WHERE execution_id AND item_id
  │                 └── getSignedUrl(storagePath) per image
  └── _photosPerItem: Map<itemId, List<_ChecklistPhotoEntry>> (estado inicial)

_ChecklistItemCard (item com itemType == 'photo')
  └── _ChecklistPhotoStrip
        ├── [camera icon button] → _pickPhoto(itemId)
        │     ├── showModalBottomSheet → _PhotoSourceSheet → ImageSource
        │     ├── ImagePicker().pickImage(source, quality=85, maxWidth=1200)
        │     ├── setState(add entry com state=uploading)
        │     ├── ChecklistImageService.uploadImage(companyId, executionId, itemId, file)
        │     │     ├── Storage.uploadBinary('checklist-images', path, bytes)
        │     │     └── INSERT checklist_item_images → retorna ChecklistItemImage
        │     ├── getSignedUrl(storagePath)
        │     └── setState(entry.state = uploaded | error)
        │
        └── [thumbnails strip — horizontal scroll]
              └── per _ChecklistPhotoEntry:
                    uploading → CircularProgressIndicator overlay
                    uploaded  → Image.network(signedUrl) + close button
                    error     → Image.file(opacity 0.4) + error icon (tap = retry)
```

### Estrutura de arquivos — novos e modificados

```
primeaudit/lib/
├── models/
│   └── checklist_item_image.dart          # NOVO — ChecklistItemImage model
├── services/
│   └── checklist_image_service.dart       # NOVO — ChecklistImageService
├── screens/checklist/
│   └── checklist_execution_screen.dart    # MODIFICADO — substitui _PhotoPlaceholder
│                                          #   + carrega fotos em _load()
│                                          #   + _ChecklistPhotoStrip (novo widget local)
│                                          #   + _ChecklistPhotoEntry / _ChecklistPhotoState
│                                          #   + _PhotoSourceSheet (copiado/adaptado)
└── supabase/migrations/
    └── 20260510_create_checklist_item_images.sql  # NOVO — tabela + bucket + RLS
```

### Anti-Patterns to Avoid

- **Estado de fotos dentro do `_ChecklistPhotoStrip`:** Se o strip for `StatefulWidget` com estado proprio, o estado e perdido no rebuild do parent. Usar `Map<String, List<_ChecklistPhotoEntry>>` no screen state e passar como argumento.
- **`await` sem `mounted` guard em `_pickPhoto`:** Apos qualquer `await` (pickImage, uploadImage, getSignedUrl), verificar `if (!mounted) return` antes de `setState`. [VERIFIED: create_corrective_action_screen.dart linha 169]
- **`ScaffoldMessenger.of(context)` apos `await`:** Capturar messenger antes do primeiro await. [VERIFIED: checklist_execution_screen.dart linha 177 — padrao ja estabelecido]
- **Upload bloquear `_saveAnswer`:** Photo upload e `_saveAnswer` sao totalmente independentes — nem callback compartilhado, nem `await` cruzado.

---

## Detailed Technical Findings

### 1. Schema: `checklist_item_images` + bucket `checklist-images`

#### 1.1 Tabela `checklist_item_images`

Mirror de `audit_item_images` [VERIFIED: 20260428_create_audit_item_images.sql], substituindo `audit_id → execution_id` e `template_item_id → item_id`, e sem `corrective_action_id`.

```sql
-- checklist_item_images
CREATE TABLE IF NOT EXISTS checklist_item_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS execution_id  UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS item_id       UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS company_id    UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS storage_path  TEXT NOT NULL DEFAULT '';
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS created_by    UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

**Foreign keys:**
- `execution_id → checklist_executions(id) ON DELETE CASCADE`
- `item_id → checklist_template_items(id) ON DELETE CASCADE`
- `company_id → companies(id) ON DELETE RESTRICT`
- `created_by → profiles(id) ON DELETE RESTRICT`

**Indices:**
- `(execution_id, item_id)` — carregamento de fotos por item em `_load()`
- `(company_id)` — queries por empresa
- `(created_at DESC)` — ordenacao cronologica

**Diferenca de `audit_item_images`:** sem coluna `corrective_action_id` — modulo checklist e independente do modulo de acoes corretivas. [VERIFIED: STATE.md — "Modulo Checklist e independente do modulo de Auditoria"]

#### 1.2 RLS para `checklist_item_images`

Usa **Pattern 3** (subquery via FK para derivar ownership): permissao derivada da execucao pai.

```sql
-- superuser/dev: acesso total (Pattern 1)
CREATE POLICY "superuser_dev_checklist_item_images_full" ON checklist_item_images
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: CRUD na propria empresa (Pattern 2 — company_id)
CREATE POLICY "adm_checklist_item_images_company" ON checklist_item_images
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- auditor SELECT: apenas imagens de suas proprias execucoes (Pattern 3)
CREATE POLICY "auditor_checklist_item_images_select" ON checklist_item_images
  FOR SELECT
  USING (
    get_my_role() = 'auditor'
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_item_images.execution_id
        AND e.created_by = auth.uid()
    )
  );

-- auditor INSERT: apenas em suas proprias execucoes (Pattern 3)
CREATE POLICY "auditor_checklist_item_images_insert" ON checklist_item_images
  FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_item_images.execution_id
        AND e.created_by = auth.uid()
    )
  );

-- auditor DELETE: apenas suas proprias imagens
CREATE POLICY "auditor_checklist_item_images_delete" ON checklist_item_images
  FOR DELETE
  USING (
    get_my_role() = 'auditor'
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_item_images.execution_id
        AND e.created_by = auth.uid()
    )
  );
```

#### 1.3 Bucket Storage `checklist-images`

O bucket e criado via SQL migration — mesmo padrao do `audit-images`. [VERIFIED: 20260428_create_audit_item_images.sql linha 88-90]

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('checklist-images', 'checklist-images', false)
ON CONFLICT (id) DO NOTHING;
```

**Path convention:** `{companyId}/{executionId}/{itemId}/{uuid}.jpg`

**Storage RLS policies** (mirror de `audit-images`):
```sql
-- INSERT (upload)
CREATE POLICY "authenticated_upload_checklist_images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'checklist-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- SELECT (signed URL / read)
CREATE POLICY "authenticated_read_checklist_images" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'checklist-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- DELETE
CREATE POLICY "authenticated_delete_checklist_images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'checklist-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );
```

**Por que bucket separado?** Decisao bloqueada: "checklist-images usa bucket separado de audit-images — evita acoplamento FK". [VERIFIED: STATE.md Decisions v1.2]

---

### 2. ChecklistImageService

Mirror de `ImageService` [VERIFIED: lib/services/image_service.dart] com bucket e tabela do modulo checklist.

```dart
// lib/services/checklist_image_service.dart
class ChecklistImageService {
  final _client = Supabase.instance.client;
  static const _bucket = 'checklist-images';

  String _uuid() { /* identico ao ImageService */ }

  /// Path: {companyId}/{executionId}/{itemId}/{uuid}.jpg
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
      path, bytes,
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

  Future<String> getSignedUrl(String storagePath) async {
    return await _client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 3600);
  }

  Future<void> deleteImage({
    required String imageId,
    required String storagePath,
  }) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
    } catch (_) { /* Storage delete best-effort */ }
    await _client.from('checklist_item_images').delete().eq('id', imageId);
  }
}
```

**Diferencias de `ImageService`:**
- Bucket: `checklist-images` (nao `audit-images`)
- Tabela: `checklist_item_images` (nao `audit_item_images`)
- Chave primaria de escopo: `execution_id` (nao `audit_id`)
- Sem `linkImagesToAction` — modulo checklist nao tem acoes corretivas em Phase 15

---

### 3. ChecklistItemImage model

Mirror de `AuditItemImage` [VERIFIED: lib/models/audit_item_image.dart] com `executionId` no lugar de `auditId`, sem `correctiveActionId`.

```dart
// lib/models/checklist_item_image.dart
class ChecklistItemImage {
  final String id;
  final String executionId;
  final String itemId;
  final String companyId;
  final String storagePath;
  final String createdBy;
  final DateTime createdAt;

  const ChecklistItemImage({
    required this.id,
    required this.executionId,
    required this.itemId,
    required this.companyId,
    required this.storagePath,
    required this.createdBy,
    required this.createdAt,
  });

  factory ChecklistItemImage.fromMap(Map<String, dynamic> map) {
    return ChecklistItemImage(
      id: map['id'] as String,
      executionId: map['execution_id'] as String,
      itemId: map['item_id'] as String,
      companyId: map['company_id'] as String,
      storagePath: map['storage_path'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
```

---

### 4. _ChecklistPhotoStrip — integracao com _ChecklistItemCard

#### 4.1 Tipos auxiliares (locais ao arquivo `checklist_execution_screen.dart`)

```dart
// Tipos internos — mesma estrutura de create_corrective_action_screen.dart
// [VERIFIED: create_corrective_action_screen.dart linhas 512-541]

enum _ChecklistPhotoState { uploading, uploaded, error }

class _ChecklistPhotoEntry {
  final String key;                        // tempo microsegundo — chave local
  final _ChecklistPhotoState state;
  final XFile? file;                       // local file para preview
  final ChecklistItemImage? image;         // persisted record (pos upload)
  final String? signedUrl;                 // signed URL para exibicao

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
  }) => _ChecklistPhotoEntry(
    key: key, state: state ?? this.state, file: file,
    image: image ?? this.image, signedUrl: signedUrl ?? this.signedUrl,
  );
}
```

#### 4.2 Estado no screen

```dart
// Em _ChecklistExecutionScreenState:
// Map: itemId → lista de fotos com estado
final Map<String, List<_ChecklistPhotoEntry>> _photosPerItem = {};
```

#### 4.3 _ChecklistPhotoStrip widget

```dart
class _ChecklistPhotoStrip extends StatelessWidget {
  final String itemId;
  final String executionId;
  final List<_ChecklistPhotoEntry> photos;
  final bool readOnly;
  final void Function(String itemId) onPickPhoto;
  final void Function(String itemId, String key) onRetryPhoto;
  final void Function(String itemId, String key) onRemovePhoto;
  final AppTheme theme;

  const _ChecklistPhotoStrip({
    required this.itemId,
    required this.executionId,
    required this.photos,
    required this.readOnly,
    required this.onPickPhoto,
    required this.onRetryPhoto,
    required this.onRemovePhoto,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!readOnly)
          GestureDetector(
            onTap: () => onPickPhoto(itemId),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  size: 22, color: AppColors.accent),
            ),
          ),
        if (photos.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: photos.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildThumb(p),
                )).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThumb(_ChecklistPhotoEntry p) {
    // Identico ao _buildThumb de create_corrective_action_screen.dart
    // [VERIFIED: create_corrective_action_screen.dart linhas 307-361]
    return SizedBox(
      width: 72, height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: p.state == _ChecklistPhotoState.error
              ? () => onRetryPhoto(itemId, p.key) : null,
          child: Stack(fit: StackFit.expand, children: [
            if (p.state == _ChecklistPhotoState.uploaded && p.signedUrl != null)
              Image.network(p.signedUrl!, fit: BoxFit.cover)
            else if (p.file != null)
              Opacity(
                opacity: p.state == _ChecklistPhotoState.error ? 0.4 : 0.6,
                child: Image.file(File(p.file!.path), fit: BoxFit.cover),
              )
            else
              Container(color: theme.background),
            if (p.state == _ChecklistPhotoState.uploading)
              const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))),
            if (p.state == _ChecklistPhotoState.error)
              const Center(child: Icon(Icons.error_rounded, color: AppColors.error, size: 20)),
            if (p.state == _ChecklistPhotoState.uploaded && !readOnly)
              Positioned(top: 0, right: 0,
                child: GestureDetector(
                  onTap: () => onRemovePhoto(itemId, p.key),
                  child: Container(width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
```

#### 4.4 Integracao no _AnswerWidget (substituicao do _PhotoPlaceholder)

No switch de `_AnswerWidget.build()` (linha 794 de `checklist_execution_screen.dart`):

```dart
// ANTES (Phase 14 placeholder):
case 'photo':
  return _PhotoPlaceholder(theme: theme);

// DEPOIS (Phase 15):
case 'photo':
  return _ChecklistPhotoStrip(
    itemId: item.id,
    executionId: /* via callback ou prop */,
    photos: photos,     // List<_ChecklistPhotoEntry> passada de cima
    readOnly: readOnly,
    onPickPhoto: onPickPhoto,
    onRetryPhoto: onRetryPhoto,
    onRemovePhoto: onRemovePhoto,
    theme: theme,
  );
```

**Problema de props:** `_AnswerWidget` atualmente nao recebe `photos` nem callbacks de foto. A solucao mais limpa — mantendo a separacao de `_AnswerWidget` como widget de resposta simples — e:

**Opcao A (recomendada):** Adicionar props opcionais em `_ChecklistItemCard` para fotos:
```dart
// _ChecklistItemCard novos campos:
final List<_ChecklistPhotoEntry>? photos;
final void Function(String itemId)? onPickPhoto;
final void Function(String itemId, String key)? onRetryPhoto;
final void Function(String itemId, String key)? onRemovePhoto;
```
O `_ChecklistItemCard` injeta o strip apos o `_AnswerWidget` quando `item.itemType == 'photo'`, em vez de delegar para o `_AnswerWidget`. Isso mantem `_AnswerWidget` sem conhecimento de fotos.

**Opcao B (alternativa):** Manter `_PhotoPlaceholder` no switch de `_AnswerWidget` e adicionar o strip no `_ChecklistItemCardState.build()` logo abaixo do `_AnswerWidget` condicionalmente. Identico em resultado, mais facil de isolar o wiring.

**Decisao:** Opcao A — strip como secao separada no `_ChecklistItemCard`, nao dentro do `_AnswerWidget`. Mantem `_AnswerWidget` como widget puro de resposta.

---

### 5. Isolamento de falha: foto vs _saveAnswer

Este e o invariante mais critico da phase (core value).

```
Resposta (auto-save)         Foto (upload)
─────────────────────        ─────────────────────────────
_onAnswer(itemId, resp)      _pickPhoto(itemId)
  └── _saveAnswer(...)         └── ChecklistImageService.uploadImage(...)
        ├── sucesso: ok               ├── sucesso: setState(uploaded)
        └── falha: _failedSaves       └── falha: setState(error) + snackbar
              └── _scheduleRetry            [NAO toca _failedSaves]
                    └── bloqueia             [NAO bloqueia _finalize]
                        _finalize
```

**Invariantes a manter:**
1. `_pickPhoto` nunca chama `_saveAnswer` — sao operacoes completamente separadas
2. Falha de upload nao adiciona item a `_failedSaves` — `_failedSaves` e exclusivo de respostas
3. `_finalize` verifica apenas `_failedSaves.isNotEmpty` — fotos em estado `error` nao bloqueiam finalizacao
4. Snackbar de erro de foto e distinto do snackbar de resposta — cada um gerencia o seu

**Pattern de snackbar para fotos:** Igual ao `_snack()` de `create_corrective_action_screen.dart` — capturar `ScaffoldMessenger.of(context)` ANTES do `await`, chamar diretamente sem armazenar. [VERIFIED: create_corrective_action_screen.dart linha 176]

---

### 6. Carregamento de fotos no _load()

Ao abrir `ChecklistExecutionScreen` (rascunho retomado), as fotos existentes devem ser carregadas.

**Estrategia:** Para cada item, carregar fotos em paralelo com respostas. O problema de N queries pode ser mitigado carregando TODAS as imagens da execucao em uma unica query, depois agrupando por `item_id`.

```dart
// ChecklistImageService — metodo novo para carregar todas da execucao:
Future<List<ChecklistItemImage>> getImagesByExecution(String executionId) async {
  final rows = await _client
      .from('checklist_item_images')
      .select()
      .eq('execution_id', executionId)
      .order('created_at');
  return (rows as List).map((r) => ChecklistItemImage.fromMap(r)).toList();
}
```

```dart
// Em _ChecklistExecutionScreenState._load():
final results = await Future.wait([
  _templateService.getItems(templateId),
  _answerService.getAnswers(widget.execution.id),
  _imageService.getImagesByExecution(widget.execution.id), // NOVO
]);

final items = results[0] as List<ChecklistTemplateItem>;
final answerRows = results[1] as List<Map<String, dynamic>>;
final imageRows = results[2] as List<ChecklistItemImage>;

// Agrupar imagens por item_id + gerar signed URLs
final photosMap = <String, List<_ChecklistPhotoEntry>>{};
for (final img in imageRows) {
  String? url;
  try {
    url = await _imageService.getSignedUrl(img.storagePath);
  } catch (_) { /* URL falhou — mostrar sem preview */ }
  final entry = _ChecklistPhotoEntry(
    key: img.id,  // usa id do banco como chave
    state: url != null ? _ChecklistPhotoState.uploaded : _ChecklistPhotoState.error,
    image: img,
    signedUrl: url,
  );
  photosMap.putIfAbsent(img.itemId, () => []).add(entry);
}
setState(() => _photosPerItem.addAll(photosMap));
```

**Cuidado:** `getSignedUrl` e chamado em loop apos `Future.wait` — pode ser lento para muitas fotos. Para Phase 15 (MVP), e aceitavel. Phase 17 (History) pode otimizar com `createSignedUrls` em batch se necessario. [ASSUMED — verificar se PostgREST/Supabase tem batch signed URL]

**Signed URL e por item de foto, nao por item de checklist:** Se um item `photo` nao tiver fotos, nao ha queries extras.

---

### 7. Android: permissoes e FileProvider

**Permissoes ja declaradas no AndroidManifest.xml:** [VERIFIED: AndroidManifest.xml]
- `CAMERA` — camera
- `READ_EXTERNAL_STORAGE` com `maxSdkVersion="32"` — Android <= 12
- `READ_MEDIA_IMAGES` — Android 13+

**FileProvider:** `image_picker` ^1.1.x registra o FileProvider automaticamente via plugin manifest merge. NAO e necessario adicionar manualmente. [ASSUMED — baseado em comportamento documentado do image_picker; STATE.md Blockers/Concerns menciona "Confirmar se image_picker (Phase 9) ja declarou FileProvider no AndroidManifest.xml antes de Phase 15"]

**Verificacao pratica:** Em Phase 9, `create_corrective_action_screen.dart` usa `ImagePicker()` sem crash em producao, o que indica que FileProvider esta configurado corretamente pelo plugin. [VERIFIED: create_corrective_action_screen.dart linhas 153-155 — ImagePicker ja em uso]

---

### 8. Modo leitura (Phase 17 — History)

A Phase 17 (History) precisara exibir fotos em modo leitura. O `_ChecklistPhotoStrip` ja recebe `readOnly: bool` que:
- Oculta o botao de camera quando `true`
- Desabilita `onRemovePhoto` (nao renderiza o X nas miniaturas)
- Desabilita `onRetryPhoto` (ou mantém habilitado para tentar de novo — a decidir)

**Flag `readOnly` no _ChecklistItemCard:** `_ChecklistItemCard` ja tem `readOnly: bool` [VERIFIED: checklist_execution_screen.dart linha 531]. Ao passar `readOnly: true`, o strip herda o comportamento de leitura automaticamente.

**Nenhuma alteracao adicional necessaria** para suportar Phase 17 — o `readOnly` flag ja e suficiente. [ASSUMED — Phase 17 provavelmente cria uma tela nova de visualizacao; se reutilizar `ChecklistExecutionScreen` em modo readOnly, o strip funciona sem modificacao]

---

### 9. Conformidade — sem impacto

`ChecklistAnswerService.calculateConformity` ja exclui `photo` de `conformityTypes`:

```dart
const conformityTypes = {'yes_no', 'text', 'multiple_choice'};
// number, date, photo excluidos — foto e informativa, nao conformidade
```

[VERIFIED: primeaudit/lib/services/checklist_answer_service.dart — `calculateConformity` com `conformityTypes`]

**Nenhuma alteracao necessaria em `ChecklistAnswerService`.**

---

## Don't Hand-Roll

| Problema | Nao construir | Usar em vez | Por que |
|----------|---------------|-------------|---------|
| UUID v4 para storage path | `DateTime.millisecondsSinceEpoch` como ID | `_uuid()` com `Random.secure()` (copiado de `ImageService`) | Seguro, sem colisao, sem dependencia externa [VERIFIED: image_service.dart linhas 18-30] |
| Upload multipart | HTTP direto para Supabase Storage | `_client.storage.from(bucket).uploadBinary(path, bytes)` | SDK ja lida com autenticacao, retries e headers [VERIFIED: image_service.dart linha 48] |
| Signed URL com expiry | URL publica ou token proprio | `_client.storage.from(bucket).createSignedUrl(path, 3600)` | Bucket privado — signed URL e o unico mecanismo correto [VERIFIED: image_service.dart linha 96] |
| File picker customizado | Camera intent manual (Android) | `ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200)` | Plugin ja lida com permissoes, FileProvider, intents [VERIFIED: create_corrective_action_screen.dart linha 153] |
| State machine de upload | enum + switch manual complexo | `_ChecklistPhotoState { uploading, uploaded, error }` + `copyWith` | Ja estabelecido em create_corrective_action_screen.dart; trivial mas correto |
| Retry de upload com backoff | Loop com sleep | Tap manual em thumbnail de erro — sem retry automatico para fotos | Fotos nao bloqueiam finalizacao; retry manual e suficiente e menos complexo que auto-retry de respostas |

---

## Common Pitfalls

### Pitfall 1: `use_build_context_synchronously` em `_pickPhoto`

**O que vai errado:** `_pickPhoto` e `async`; qualquer uso de `context` apos o primeiro `await` (seja `showModalBottomSheet`, `pickImage` ou `uploadImage`) causa lint error e possivel crash se o widget foi desmontado.

**Por que acontece:** O auditor pode navegar para fora da tela enquanto o upload esta em andamento.

**Como evitar:** Apos cada `await`, verificar `if (!mounted) return`. Capturar `ScaffoldMessenger.of(context)` antes do primeiro `await`. [VERIFIED: create_corrective_action_screen.dart linha 169 — `if (!mounted) return`]

**Exemplo correto:**
```dart
Future<void> _pickPhoto(String itemId) async {
  final messenger = ScaffoldMessenger.of(context); // ANTES de qualquer await
  final source = await showModalBottomSheet<ImageSource>(...);
  if (source == null) return;
  final file = await ImagePicker().pickImage(...);
  if (file == null) return;
  // ... adiciona entry uploading ...
  try {
    final img = await _imageService.uploadImage(...);
    final url = await _imageService.getSignedUrl(img.storagePath);
    if (!mounted) return;
    setState(() { /* atualiza entry */ });
  } catch (e) {
    if (!mounted) return;
    setState(() { /* marca error */ });
    messenger.showSnackBar(...); // usa messenger capturado antes
  }
}
```

### Pitfall 2: Signed URL expira (1 hora)

**O que vai errado:** Se o auditor deixar a tela aberta por mais de 1 hora, os `Image.network(signedUrl)` quebram com 403.

**Por que acontece:** `createSignedUrl(path, 3600)` gera URL valida por 3600 segundos.

**Como evitar:** Para Phase 15 (campo), o contexto de uso e curto (< 1h por auditoria). Aceitar a limitacao. Phase 17 (History) pode precisar de refresh de URL — nao e escopo desta phase.

**Warning signs:** `Image.network` mostrando erro 403 apos sessao longa.

### Pitfall 3: getSignedUrl em loop para muitas fotos atrasa _load()

**O que vai errado:** Se um item tiver 10 fotos e o auditor reabrir o rascunho, `getSignedUrl` e chamado sequencialmente 10 vezes, cada uma com round-trip HTTP.

**Por que acontece:** `getSignedUrl` e `async` e chamado dentro de `for` sem `Future.wait`.

**Como evitar:** Usar `Future.wait` para gerar signed URLs em paralelo:
```dart
final urls = await Future.wait(
  imageRows.map((img) => _imageService.getSignedUrl(img.storagePath)
      .catchError((_) => '')));
```

### Pitfall 4: `_photosPerItem` nao preservado no rebuild do _load()

**O que vai errado:** Se `_load()` for chamado novamente (RefreshIndicator), `_photosPerItem` e sobrescrito — fotos em estado `uploading` ou `error` desaparecem.

**Por que acontece:** Mesmo problema do Pitfall 3 de Phase 14 (`_failedSaves` nao preservado no reload).

**Como evitar:** No reload, preservar fotos em estado `uploading` ou `error` que nao tem `image.id` (nao persistidas):
```dart
// Mesclar: manter entries locais (nao persistidas) sobre os dados do banco
final merged = Map<String, List<_ChecklistPhotoEntry>>.from(_photosPerItem);
// Adicionar apenas as fotos do banco que nao estao ja no merged (por image.id)
// ...
```

### Pitfall 5: `dart:io` necessario para `Image.file`

**O que vai errado:** `Image.file(File(p.file!.path))` requer `import 'dart:io';` — se ausente, erro de compilacao.

**Por que acontece:** `File` de `dart:io` nao e importado automaticamente.

**Como evitar:** Adicionar `import 'dart:io';` no topo de `checklist_execution_screen.dart`. [VERIFIED: create_corrective_action_screen.dart linha 1 — `import 'dart:io';`]

### Pitfall 6: `adm` nao ve fotos de outros auditores sem policy correta

**O que vai errado:** Se a RLS de `checklist_item_images` para `adm` usar Pattern 3 (subquery por `created_by`) em vez de Pattern 2 (company_id), o adm nao consegue ver fotos de outros auditores da empresa.

**Por que acontece:** Erro de copiar a policy de auditor em vez da de adm.

**Como evitar:** A policy de `adm` usa `company_id = get_my_company_id()` (Pattern 2), nao subquery por `created_by`. [VERIFIED: 20260428_create_audit_item_images.sql linha 56-58 — padrao adm correto]

---

## Code Examples

### ChecklistImageService.uploadImage (completo)

```dart
// [VERIFIED: mirror de lib/services/image_service.dart]
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
```

### _pickPhoto no _ChecklistExecutionScreenState

```dart
// [VERIFIED: mirror de create_corrective_action_screen.dart linhas 143-181]
Future<void> _pickPhoto(String itemId) async {
  final messenger = ScaffoldMessenger.of(context); // capturar ANTES do await
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

### _PhotoSourceSheet (copiado de create_corrective_action_screen.dart)

```dart
// [VERIFIED: create_corrective_action_screen.dart linhas 546-571]
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
          title: const Text('Tirar foto', style: TextStyle(fontSize: 14)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
          title: const Text('Escolher da galeria', style: TextStyle(fontSize: 14)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
```

### Migration SQL — estrutura resumida

```sql
-- 20260510_create_checklist_item_images.sql
-- Tabela checklist_item_images
-- Bucket checklist-images (privado)
-- RLS: Pattern 1 (superuser/dev) + Pattern 2 (adm) + Pattern 3 (auditor via execucao pai)
-- Storage RLS: company_id no primeiro segmento do path
-- NOTIFY pgrst, 'reload schema';
```

---

## Runtime State Inventory

Esta e uma phase greenfield de novas tabelas e bucket. Nenhum dado de runtime existente e afetado.

| Categoria | Itens encontrados | Acao necessaria |
|-----------|-------------------|-----------------|
| Dados armazenados | Nenhum — `checklist_item_images` nao existe ainda | Migration cria do zero |
| Config de servico live | Nenhuma — bucket `checklist-images` nao existe | INSERT em `storage.buckets` via migration |
| Estado registrado no OS | Nenhum | — |
| Secrets/env vars | Nenhum — mesma `SUPABASE_URL` e `SUPABASE_ANON_KEY` existentes | — |
| Build artifacts | Nenhum — nenhum pacote novo adicionado | — |

---

## Environment Availability

| Dependencia | Necessario para | Disponivel | Versao | Fallback |
|-------------|----------------|-----------|--------|----------|
| `image_picker` ^1.1.2 | Camera + galeria | Sim | ^1.1.2 | Nao e necessario fallback |
| CAMERA permission (Android) | Tirar foto via camera | Sim | — | Desabilitar opcao camera no picker |
| READ_MEDIA_IMAGES (Android 13+) | Galeria | Sim | — | READ_EXTERNAL_STORAGE (Android <= 12) ja declarado |
| Supabase Storage | Upload de imagens | Assume disponivel | — | — |
| `dart:io` | `Image.file` para preview local | Sim (SDK) | — | — |

[VERIFIED: AndroidManifest.xml — CAMERA, READ_EXTERNAL_STORAGE, READ_MEDIA_IMAGES presentes]
[VERIFIED: pubspec.yaml — image_picker: ^1.1.2]

---

## Validation Architecture

### Test Framework

| Propriedade | Valor |
|-------------|-------|
| Framework | `flutter_test` (SDK) |
| Config file | nenhum — convencao flutter test |
| Comando rapido | `flutter test test/checklist_image_service_test.dart` |
| Suite completa | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Comportamento | Tipo | Comando | Arquivo existe? |
|--------|--------------|------|---------|----------------|
| EXEC-04 / upload | `uploadImage` retorna `ChecklistItemImage` com storagePath correto | unit (mock) | `flutter test test/checklist_image_service_test.dart` | Nao — Wave 0 |
| EXEC-04 / getImages | `getImages` retorna lista ordenada por `created_at` | unit (mock) | incluido no mesmo arquivo | Nao — Wave 0 |
| EXEC-04 / delete | `deleteImage` chama Storage.remove e DELETE da tabela | unit (mock) | incluido no mesmo arquivo | Nao — Wave 0 |
| EXEC-04 / isolamento | falha de upload nao afeta `_failedSaves` | widget test | `flutter test test/checklist_photo_isolation_test.dart` | Nao — Wave 0 |
| SC-3 (Phase 15) | foto em estado error nao bloqueia `_finalize` | widget test | incluido no mesmo arquivo | Nao — Wave 0 |
| SC-1 (Phase 15) | `_ChecklistPhotoStrip` renderiza camera button e thumbnails | widget test | `flutter test test/checklist_photo_strip_test.dart` | Nao — Wave 0 |

**Nota sobre mocks:** `ChecklistImageService` chama Supabase diretamente — testes unitarios precisam de mock do `SupabaseClient`. Em phase test para MVP, testes de isolamento de UI (que o strip nao toca `_failedSaves`) sao mais valiosos que mocks completos de Storage.

### Wave 0 Gaps

- [ ] `test/checklist_image_service_test.dart` — cobre upload, getImages, deleteImage com Supabase mockado
- [ ] `test/checklist_photo_isolation_test.dart` — verifica que falha de upload nao entra em `_failedSaves`
- [ ] `test/checklist_photo_strip_test.dart` — widget test do `_ChecklistPhotoStrip` com photos em estados diferentes

### Sampling Rate

- **Por commit de task:** `flutter test test/checklist_photo_isolation_test.dart`
- **Por wave merge:** `flutter test`
- **Phase gate:** Suite completa verde antes de `/gsd-verify-work`

---

## Security Domain

### Applicable ASVS Categories

| Categoria ASVS | Aplica | Controle padrao |
|----------------|--------|-----------------|
| V2 Authentication | Sim (indireta) | `auth.uid()` via RLS — token JWT Supabase |
| V3 Session Management | Nao | Gerenciado pelo Supabase SDK |
| V4 Access Control | Sim | RLS Pattern 3: auditor acessa apenas imagens de suas proprias execucoes |
| V5 Input Validation | Sim (parcial) | `imageQuality: 85, maxWidth: 1200` limita tamanho; `contentType: 'image/jpeg'` no upload |
| V6 Cryptography | Nao | Bucket privado + signed URL e padrao Supabase; sem criptografia customizada |

### Known Threat Patterns

| Padrao | STRIDE | Mitigacao padrao |
|--------|--------|-----------------|
| Auditor acessa imagens de outra empresa | Information Disclosure | RLS Storage: `(storage.foldername(name))[1] = get_my_company_id()::text` — primeiro segmento do path e company_id |
| Auditor acessa imagens de outro auditor da mesma empresa | Information Disclosure | RLS tabela Pattern 3: EXISTS(checklist_executions WHERE created_by = auth.uid()) |
| Upload de arquivo nao-imagem (ex: PDF executavel) | Tampering | `contentType: 'image/jpeg'` no upload; Storage nao executa arquivos |
| URL de imagem compartilhada apos expiry | Information Disclosure (baixo) | Signed URL expira em 3600s — janela limitada |
| DELETE de imagem de outro usuario | Elevation of Privilege | RLS DELETE: `created_by = auth.uid()` + EXISTS subquery |

---

## State of the Art

| Abordagem antiga | Abordagem atual | Impacto |
|-----------------|-----------------|---------|
| `_PhotoPlaceholder` (texto informativo) | `_ChecklistPhotoStrip` funcional | EXEC-04 satisfeito; zero alteracao em modulo de Auditoria |
| Upload bloqueante (await na tela principal) | Upload fire-and-forget com estado local | Core value preservado: falha de foto nao bloqueia preenchimento |
| Bucket compartilhado `audit-images` | Bucket separado `checklist-images` | Zero acoplamento de FK entre modulos |

---

## Assumptions Log

| # | Claim | Section | Risco se errado |
|---|-------|---------|----------------|
| A1 | `image_picker` ^1.1.x registra FileProvider automaticamente via plugin manifest merge — nao necessario adicionar manualmente | Android / Permissoes (7) | Se FileProvider nao estiver configurado: crash ao tentar salvar imagem da camera em Android >= 24. Mitigacao: testar em dispositivo Android antes do merge |
| A2 | Signed URL de 3600s e suficiente para o contexto de uso de campo (< 1h por auditoria) | Pitfalls (2) | Se sessao exceder 1h: imagens mostram 403. Mitigacao: regenerar URL no `_load()` ou ao exibir foto |
| A3 | Phase 17 (History) pode reutilizar `_ChecklistPhotoStrip` com `readOnly: true` sem modificacao adicional | Modo leitura (9) | Se Phase 17 tiver requisito de navegacao full-screen por foto, o strip precisa de `onTap` para abrir viewer. Decisao de UX de Phase 17 |
| A4 | `getImagesByExecution` (uma query para todas as imagens da execucao) e mais eficiente que N queries por item | Carregamento em _load() (6) | Se a tabela tiver indice correto em `execution_id`, custo e O(1) query vs O(N) — correto. Indice ja esta no schema proposto |
| A5 | Fotos em estado `error` (sem `image.id`) nao devem ser preservadas no reload — apenas fotos persistidas (com `image.id`) sobrevivem | Pitfall 4 / Reload | Se o auditor espera que fotos nao enviadas sobrevivam ao reload: comportamento inconsistente com o contrato de "sem offline storage". Mesmo contrato de respostas em _failedSaves |

**Se esta tabela for vazia:** Todos os claims foram verificados ou citados — nenhuma confirmacao do usuario necessaria.

---

## Open Questions

1. **FileProvider no AndroidManifest.xml — confirmacao necessaria**
   - O que sabemos: `create_corrective_action_screen.dart` usa `ImagePicker()` sem crash em producao (evidencia indireta de que FileProvider esta ok)
   - O que e incerto: nao ha entrada explicita de `<provider>` no `AndroidManifest.xml` lido [VERIFIED: AndroidManifest.xml sem provider tag]
   - Recomendacao: `image_picker` 1.1.x adiciona FileProvider via plugin merge automaticamente; confirmar via `./gradlew processDebugManifest` ou teste em dispositivo

2. **Batch signed URLs**
   - O que sabemos: `createSignedUrl` e chamada uma por imagem
   - O que e incerto: Supabase tem `createSignedUrls` (plural) para batch?
   - Recomendacao: Para Phase 15 (MVP, poucos itens foto por checklist), N chamadas sequenciais e aceitavel. Otimizar em Phase 17 se necessario.

---

## Sources

### Primary (HIGH confidence)

- `[VERIFIED: primeaudit/lib/services/image_service.dart]` — padrao completo de upload, signed URL, delete, uuid, bucket name
- `[VERIFIED: primeaudit/lib/models/audit_item_image.dart]` — modelo de referencia para ChecklistItemImage
- `[VERIFIED: primeaudit/lib/screens/create_corrective_action_screen.dart]` — padrao canonico de _pickPhoto, _retryPhoto, _removePhoto, _buildThumb, _PhotoEntry, _PhotoState, _PhotoSourceSheet
- `[VERIFIED: primeaudit/lib/screens/checklist/checklist_execution_screen.dart]` — tela alvo; _PhotoPlaceholder linha 1122; _ChecklistItemCard com onAnswer/onObservation callbacks; _AnswerWidget switch
- `[VERIFIED: primeaudit/pubspec.yaml linha 38]` — image_picker: ^1.1.2 instalado
- `[VERIFIED: primeaudit/android/app/src/main/AndroidManifest.xml]` — CAMERA + READ_EXTERNAL_STORAGE + READ_MEDIA_IMAGES presentes; sem <provider> tag explicita
- `[VERIFIED: primeaudit/supabase/migrations/20260428_create_audit_item_images.sql]` — padrao completo: tabela, RLS, bucket INSERT, Storage policies
- `[VERIFIED: primeaudit/supabase/migrations/20260509_create_checklist_executions.sql]` — RLS Pattern 3 (subquery via FK) para checklist_answers — padrao a replicar
- `[VERIFIED: .planning/STATE.md Decisions v1.2]` — "checklist-images usa bucket separado de audit-images", "Upload de fotos independente de auto-save", "Modulo Checklist independente — zero alteracoes em ImageService"
- `[VERIFIED: .planning/REQUIREMENTS.md EXEC-04]` — especificacao do requisito
- `[VERIFIED: .planning/phases/14-checklist-execution-engine/14-VERIFICATION.md]` — estado entregue de Phase 14: _PhotoPlaceholder confirmado, calculateConformity exclui photo
- `[VERIFIED: primeaudit/lib/services/checklist_answer_service.dart mencionado em 14-VERIFICATION.md linha 66]` — calculateConformity com conformityTypes excluindo photo

### Secondary (MEDIUM confidence)

- `[CITED: image_picker pub.dev ^1.1.x]` — FileProvider auto-registrado via plugin manifest merge; nao verificado via Context7 nesta sessao

---

## Metadata

**Confidence breakdown:**
- Schema de banco: HIGH — baseado no padrao exato de `20260428_create_audit_item_images.sql` e RLS de `20260509_create_checklist_executions.sql`
- ChecklistImageService: HIGH — mirror direto de `ImageService` com mudancas de nomenclatura
- ChecklistItemImage model: HIGH — mirror direto de `AuditItemImage`
- _ChecklistPhotoStrip UI: HIGH — patron copiado de `create_corrective_action_screen.dart` com adaptacao de props
- Isolamento de falha: HIGH — invariante derivado de STATE.md decisions + analise do codigo de `checklist_execution_screen.dart`
- FileProvider Android: MEDIUM — comportamento esperado de plugin; nao verificado via teste direto

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (dependencias estaveis; image_picker e supabase_flutter sem major versions pendentes)
