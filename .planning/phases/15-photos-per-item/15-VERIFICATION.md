---
phase: 15-photos-per-item
verified: 2026-05-07T20:00:00Z
status: human_needed
score: 7/7 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Abrir ChecklistExecutionScreen em item do tipo 'photo' e tocar o ícone de câmera"
    expected: "Bottom sheet exibe opções 'Tirar foto' e 'Escolher da galeria'; ao selecionar fonte e tirar/escolher uma foto, miniatura 72x72 aparece inline com estado 'uploading' (CircularProgressIndicator visível) e depois muda para 'uploaded' (imagem carregada)"
    why_human: "Fluxo envolve câmera/galeria nativas do dispositivo, ImagePicker plugin, e rede para upload ao Supabase Storage — não verificável via grep ou flutter analyze"
  - test: "Forçar falha de upload (desligar WiFi antes de tocar câmera) e verificar que a finalização ainda é possível"
    expected: "Miniatura exibe ícone de erro (Icons.error_rounded); snackbar 'Upload falhou: ...' aparece; botão de finalizar não fica desabilitado; ao tocar finalizar, o checklist conclui normalmente sem mensagem sobre fotos"
    why_human: "Comportamento de rede real; não é possível simular a ausência de conectividade sem executor real"
  - test: "Reabrir rascunho de checklist que já tem fotos salvas"
    expected: "Fotos existentes carregam como miniaturas com signed URLs; uma única query é feita (getImagesByExecution), não N queries por item"
    why_human: "Requer banco remoto com dados reais e verificação de tráfego de rede via logs do Supabase"
---

# Phase 15: Photos per Item — Verification Report

**Phase Goal:** Permitir que auditores anexem fotos por item durante a execução de checklists. Cada item do tipo 'photo' exibe um strip de miniaturas com botão de câmera, estados uploading/uploaded/error, e retry/remove. Falha de upload nunca compromete o auto-save de respostas nem bloqueia a finalização (Core Value). Ao reabrir um rascunho, fotos existentes carregam em uma única query.
**Verified:** 2026-05-07T20:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Migration SQL cria checklist_item_images com RLS Pattern 3 (auditor acessa apenas suas próprias execuções via subquery EXISTS) | VERIFIED | `20260510_create_checklist_item_images.sql` linhas 62-100: `CREATE POLICY "auditor_checklist_item_images_select"... AND EXISTS (SELECT 1 FROM checklist_executions e WHERE e.id = checklist_item_images.execution_id AND e.created_by = auth.uid())` |
| 2 | ChecklistItemImage parseia todos os campos corretamente via fromMap | VERIFIED | `checklist_item_image.dart`: factory `fromMap` mapeia `id`, `execution_id`, `item_id`, `company_id`, `storage_path`, `created_by`, `created_at`; sem campo `correctiveActionId`; sem imports |
| 3 | ChecklistImageService usa bucket 'checklist-images' e tabela 'checklist_item_images' sem tocar ImageService | VERIFIED | `checklist_image_service.dart` linha 17: `static const _bucket = 'checklist-images'`; linha 57: `.from('checklist_item_images')`; comentário docstring: "Módulo independente — não altera nem depende de [ImageService] ou [AuditItemImage]"; grep confirma zero referências cruzadas |
| 4 | Falha de upload nunca toca _failedSaves nem bloqueia _finalize | VERIFIED | `checklist_execution_screen.dart` linhas 218-232: catch block de `_pickPhoto` executa apenas `setState(error)` + `messenger.showSnackBar`; `_failedSaves` aparece exclusivamente em `_saveAnswer`, `_scheduleRetry` e `_finalize`; linha 391: `if (_failedSaves.isNotEmpty)` é o único guard de `_finalize` |
| 5 | getImagesByExecution carrega todas as imagens de uma execução em uma única query | VERIFIED | `checklist_image_service.dart` linhas 85-92: `getImagesByExecution` faz `.from('checklist_item_images').select().eq('execution_id', executionId).order('created_at')` — uma única query; `checklist_execution_screen.dart` linha 81: chamado dentro de `Future.wait([...])` no `_load()` |
| 6 | _PhotoPlaceholder foi removido e substituído por _ChecklistPhotoStrip funcional | VERIFIED | Grep em `checklist_execution_screen.dart` para `_PhotoPlaceholder` retorna zero resultados; `class _ChecklistPhotoStrip` existe na linha 1387 com `build()` completo (camera button, scroll horizontal, thumbnails 72x72, CircularProgressIndicator, Icons.error_rounded); `case 'photo'` retorna `SizedBox.shrink()` |
| 7 | Bucket checklist-images declarado como privado e separado do bucket audit-images | VERIFIED | Migration SQL linha 104-106: `INSERT INTO storage.buckets (id, name, public) VALUES ('checklist-images', 'checklist-images', false)`; service usa `_bucket = 'checklist-images'`; nenhuma referência a `audit-images` nos novos arquivos |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql` | Tabela + bucket + RLS Pattern 3 | VERIFIED | 141 linhas; idempotente; 4 FKs; 3 índices; RLS completo (Pattern 1/2/3); bucket privado; NOTIFY pgrst; sem corrective_action_id |
| `primeaudit/lib/models/checklist_item_image.dart` | ChecklistItemImage com fromMap | VERIFIED | 39 linhas; sem imports; const constructor; 7 campos; factory fromMap correto; sem correctiveActionId |
| `primeaudit/lib/services/checklist_image_service.dart` | ChecklistImageService com bucket checklist-images | VERIFIED | 117 linhas; 5 métodos (uploadImage, getImages, getImagesByExecution, getSignedUrl, deleteImage); UUID v4 sem dependência; isolamento total |
| `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` | Tela modificada com _ChecklistPhotoStrip | VERIFIED | Imports dart:io e image_picker adicionados; _imageService + _photosPerItem no state; _load() estendido; _pickPhoto/_retryPhoto/_removePhoto adicionados; _ChecklistPhotoStrip/Entry/State/PhotoSourceSheet no final do arquivo |
| `primeaudit/test/checklist_item_image_test.dart` | Testes de fromMap | VERIFIED | 2 testes: parses all fields correctly + has no correctiveActionId |
| `primeaudit/test/checklist_image_service_test.dart` | Contrato de service | VERIFIED | 2 testes: storage path format + contract documented |
| `primeaudit/test/checklist_photo_isolation_test.dart` | Invariante de isolamento | VERIFIED | 2 testes: _failedSaves not modified + _finalize check |
| `primeaudit/test/checklist_photo_strip_test.dart` | Widget tests do strip (substituídos de stubs para reais em Plan 15-03) | VERIFIED | 9 testes reais: state machine, _photosPerItem management, _failedSaves independence — mocks locais sem depender de classe privada |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `checklist_image_service.dart` | `checklist_item_images` (table) | `.from('checklist_item_images').insert(...)` | WIRED | Linha 57: `_client.from('checklist_item_images').insert({...})` |
| `checklist_image_service.dart` | `checklist-images` (bucket) | `_client.storage.from('checklist-images')` | WIRED | `static const _bucket = 'checklist-images'`; usado em uploadBinary, remove, createSignedUrl |
| `ChecklistItemImage.fromMap` | `execution_id / item_id` columns | `map['execution_id'] / map['item_id']` | WIRED | Linhas 32-33 do model: `executionId: map['execution_id'] as String`, `itemId: map['item_id'] as String` |
| `_ChecklistExecutionScreenState._pickPhoto` | `ChecklistImageService.uploadImage` | `_imageService.uploadImage(companyId, executionId, itemId, file)` | WIRED | Linhas 198-204: chama `_imageService.uploadImage(...)` dentro do try block |
| `_ChecklistExecutionScreenState._load` | `ChecklistImageService.getImagesByExecution` | `Future.wait([..., _imageService.getImagesByExecution(widget.execution.id)])` | WIRED | Linha 81: `_imageService.getImagesByExecution(widget.execution.id)` no Future.wait de 3 elementos |
| `_ChecklistItemCard` | `_ChecklistPhotoStrip` | `Padding(child: _ChecklistPhotoStrip(...))` | WIRED | Linhas 828-835: condicional `if (widget.item.itemType == 'photo' && widget.photos != null)` renderiza o strip |
| `_pickPhoto (catch block)` | `SnackBar (isolado de _failedSaves)` | `messenger.showSnackBar(...)` capturado ANTES do primeiro await | WIRED | Linha 175: `final messenger = ScaffoldMessenger.of(context)` antes de qualquer await; linha 227: `messenger.showSnackBar(...)` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `_ChecklistPhotoStrip` | `photos` (List\<_ChecklistPhotoEntry\>) | `_photosPerItem[item.id]` no `_ChecklistItemCard` | Sim — populado por `getImagesByExecution` (banco) ou `uploadImage` (Storage) | FLOWING |
| `_load()` signed URLs | `urls` | `Future.wait(imageRows.map(getSignedUrl))` | Sim — chamada real ao Supabase Storage `createSignedUrl` | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED para comportamentos de câmera/galeria/rede — requerem dispositivo físico ou emulador com Supabase remoto. Verificações estáticas executadas:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| flutter analyze 3 arquivos Dart | `flutter analyze lib/models/checklist_item_image.dart lib/services/checklist_image_service.dart lib/screens/checklist/checklist_execution_screen.dart` | No issues found | PASS |
| 14 testes da fase | `flutter test test/checklist_item_image_test.dart ... checklist_photo_strip_test.dart` | 14/14 passed | PASS |
| Isolamento de módulo — checklist_image_service.dart | grep ImageService/AuditItemImage/audit-images | Apenas comentário docstring, sem import ou uso | PASS |
| _PhotoPlaceholder ausente | grep _PhotoPlaceholder em checklist_execution_screen.dart | Zero resultados | PASS |
| _failedSaves não tocado no catch de _pickPhoto | Análise manual das linhas 218-232 | Catch contém apenas setState(error) + snackbar | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| EXEC-04 | 15-01, 15-02, 15-03 | Usuário anexa foto(s) por item via câmera ou galeria | SATISFIED (programático) | Migration criada e aplicada; service com uploadImage; UI com _ChecklistPhotoStrip funcional integrada na tela de execução; isolamento de falha verificado via testes |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `test/checklist_image_service_test.dart` linha 31 | `expect(true, isTrue)` — placeholder documentado | Info | Não afeta o goal; teste documenta explicitamente que o isolamento real é testado em `checklist_photo_isolation_test.dart`; intencionalmente deixado como marcador de contrato |

Nenhum anti-padrão blocker encontrado. O placeholder em `checklist_image_service_test.dart` é declarado explicitamente como documentação de contrato.

### Human Verification Required

#### 1. Fluxo completo de câmera/galeria → miniatura inline

**Test:** Abrir a ChecklistExecutionScreen em um item do tipo 'photo' e tocar o ícone de câmera
**Expected:** Bottom sheet exibe opções 'Tirar foto' e 'Escolher da galeria'; ao selecionar uma fonte e capturar/escolher uma imagem, a miniatura 72x72 aparece inline com CircularProgressIndicator durante o upload, depois exibe a imagem carregada (estado uploaded)
**Why human:** Envolve câmera/galeria nativas do dispositivo Android, ImagePicker plugin, e upload real ao Supabase Storage `checklist-images` — não verificável via análise estática

#### 2. Isolamento de falha de upload em dispositivo real

**Test:** Desligar WiFi/dados antes de tocar o ícone de câmera, selecionar uma foto
**Expected:** Miniatura aparece com ícone de erro (Icons.error_rounded); snackbar 'Upload falhou: ...' é exibido; o preenchimento das demais respostas continua normalmente; o botão de finalizar não é bloqueado; ao tocar finalizar, o checklist conclui sem nenhuma mensagem sobre fotos com erro
**Why human:** Requer ausência real de conectividade de rede; a lógica de isolamento foi verificada estaticamente mas o comportamento end-to-end com a UI depende do executor real

#### 3. Carregamento de fotos ao reabrir rascunho

**Test:** Salvar um rascunho com 2-3 fotos em um item, fechar o app, reabrir a execução do mesmo rascunho
**Expected:** As miniaturas das fotos existentes aparecem no strip (estado uploaded com signed URLs); o carregamento ocorre em uma única query (verificável via Supabase logs ou Flutter DevTools)
**Why human:** Requer banco remoto com dados persistidos e verificação de tráfego de rede; o código (`getImagesByExecution` em `Future.wait`) foi verificado estaticamente como query única, mas o comportamento no dispositivo precisa ser confirmado

### Gaps Summary

Nenhum gap blocker encontrado. Todos os 7 must-haves verificados no codebase. O status `human_needed` deve-se exclusivamente aos comportamentos de runtime que requerem dispositivo real (câmera, rede, banco remoto), não a falhas de implementação.

---

_Verified: 2026-05-07T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
