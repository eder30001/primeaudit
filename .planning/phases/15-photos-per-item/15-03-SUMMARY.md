---
phase: 15-photos-per-item
plan: 03
subsystem: ui
tags: [flutter, dart, image_picker, checklist, photos, widget-test]

# Dependency graph
requires:
  - phase: 15-01
    provides: ChecklistImageService (uploadImage, getImagesByExecution, getSignedUrl, deleteImage), ChecklistItemImage model
  - phase: 15-02
    provides: Tabela checklist_item_images e bucket checklist-images ativos no banco remoto

provides:
  - ChecklistExecutionScreen com _ChecklistPhotoStrip funcional integrado
  - _pickPhoto / _retryPhoto / _removePhoto no screen state com isolamento total de _failedSaves
  - _load() estendido com getImagesByExecution + signed URLs em paralelo
  - Widget tests de contrato para state machine e invariante de isolamento

affects:
  - 16-digital-signature (usa ChecklistExecutionScreen como base)
  - 17-history (strip com readOnly=true pronto para uso)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "messenger capturado antes do primeiro await em _pickPhoto (use_build_context_synchronously compliance)"
    - "Signed URLs geradas em paralelo via Future.wait + catchError para evitar N chamadas sequenciais"
    - "Estado de fotos no Map<itemId, List<_ChecklistPhotoEntry>> no screen state — mesmo padrao de _answers"
    - "_ChecklistPhotoStrip como StatelessWidget com callbacks — estado gerenciado pelo parent"
    - "if (!mounted) return apos cada await em async methods"

key-files:
  created:
    - primeaudit/test/checklist_photo_strip_test.dart (substituido — conteudo real)
  modified:
    - primeaudit/lib/screens/checklist/checklist_execution_screen.dart

key-decisions:
  - "Strip de fotos renderizado abaixo do _AnswerWidget no _ChecklistItemCard (Opcao A da RESEARCH) — mantem _AnswerWidget puro sem conhecimento de fotos"
  - "case 'photo' em _AnswerWidget retorna SizedBox.shrink — strip gerenciado pelo card pai"
  - "_PhotoPlaceholder removida inteiramente — substituida por _ChecklistPhotoStrip funcional"
  - "Testes de widget usam mocks locais (_MockPhotoEntry, _MockPhotoState) para verificar contratos sem instanciar classe privada"

patterns-established:
  - "Photo upload isolation: _pickPhoto nunca toca _failedSaves — estados de foto e de resposta completamente separados"
  - "Signed URLs paralelas: Future.wait(imageRows.map(getSignedUrl).catchError) — evita N+1 no _load()"
  - "_ChecklistPhotoState enum: uploading → uploaded | error (state machine minima)"

requirements-completed: [EXEC-04]

# Metrics
duration: 30min
completed: 2026-05-07
---

# Phase 15 Plan 03: UI _ChecklistPhotoStrip integrada na ChecklistExecutionScreen Summary

**_ChecklistPhotoStrip funcional com camera icon, miniaturas 72x72, upload uploading/uploaded/error e isolamento total de _failedSaves — EXEC-04 entregue ponta a ponta**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-05-07
- **Completed:** 2026-05-07
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `checklist_execution_screen.dart` modificado: imports novos, _imageService + _photosPerItem no state, _load() estendido com getImagesByExecution + signed URLs em paralelo, _pickPhoto/_retryPhoto/_removePhoto adicionados com isolamento total de _failedSaves
- `_ChecklistItemCard` atualizado com props opcionais de foto e _ChecklistPhotoStrip renderizado abaixo do _AnswerWidget
- `_PhotoPlaceholder` removida; `case 'photo'` em `_AnswerWidget` retorna `SizedBox.shrink()`
- Novos tipos ao final do arquivo: `_ChecklistPhotoState` enum, `_ChecklistPhotoEntry` class, `_PhotoSourceSheet` widget, `_ChecklistPhotoStrip` widget
- Widget tests atualizados: 9 testes reais cobrindo state machine (copyWith, uploading, error, uploaded), _photosPerItem management, e invariante SC-3 (_failedSaves independence + _finalize não bloqueado por photo error)
- `flutter analyze` limpo (0 issues); `flutter test` 293/293 testes passando

## Task Commits

1. **Task 1: integrar _ChecklistPhotoStrip na ChecklistExecutionScreen** - `43d5289` (feat)
2. **Task 2: atualizar widget tests _ChecklistPhotoStrip** - `3b2e102` (test)

**Plan metadata:** (este commit)

## Files Created/Modified

- `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` - Tela principal com _ChecklistPhotoStrip integrado, _pickPhoto/_retryPhoto/_removePhoto, _load() estendido, _PhotoPlaceholder removida
- `primeaudit/test/checklist_photo_strip_test.dart` - Widget tests reais substituindo stubs do Plan 15-01

## Decisions Made

- Strip renderizado abaixo do _AnswerWidget no _ChecklistItemCard (Opcao A da RESEARCH) — `_AnswerWidget` permanece puro, sem conhecimento de fotos; limita o escopo de mudanca
- `case 'photo'` retorna `SizedBox.shrink()` (nao o strip diretamente) — strip recebe props completas do card pai, incluindo callbacks com itemId
- Testes usam `_MockPhotoEntry` / `_MockPhotoState` locais em vez de importar a classe privada — testa o contrato (state machine + isolamento) sem acoplar ao arquivo de implementacao

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Banco remoto ja configurado em Plan 15-02.

## Known Stubs

Nenhum. Os stubs de `checklist_photo_strip_test.dart` foram substituidos por testes reais. A implementacao de _ChecklistPhotoStrip esta completa e funcional.

## Threat Flags

Nenhum novo surface introduzido alem dos ja registrados no threat_model de 15-03-PLAN.md (T-15-08, T-15-09, T-15-10, T-15-11).

Mitigacoes implementadas:
- T-15-08 (use_build_context_synchronously): messenger capturado antes do primeiro await; if (!mounted) return apos cada await
- T-15-09 (Upload bloqueia _finalize): _pickPhoto fire-and-forget; _finalize verifica apenas _failedSaves.isEmpty; foto em error nao bloqueia

## Next Phase Readiness

- Phase 15 completa: tabela + bucket + RLS (15-01), migration aplicada (15-02), UI funcional (15-03)
- EXEC-04 satisfeito ponta a ponta: auditor toca camera icon → seleciona fonte → foto aparece como miniatura com estado uploading → uploaded | error
- _ChecklistPhotoStrip ja suporta readOnly=true — Phase 17 (History) pode reutilizar sem modificacao adicional
- Nenhum bloqueio identificado para Phase 16 (Digital Signature)

---

## Self-Check: PASSED

Files verified present:
- `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` - FOUND (modificado)
- `primeaudit/test/checklist_photo_strip_test.dart` - FOUND (atualizado)

Commits verified:
- `43d5289` (feat(15-03): integrar _ChecklistPhotoStrip na ChecklistExecutionScreen) - FOUND
- `3b2e102` (test(15-03): atualizar widget tests _ChecklistPhotoStrip — state machine e isolamento) - FOUND

Analysis: flutter analyze lib/screens/checklist/checklist_execution_screen.dart — No issues found
Tests: flutter test 293/293 tests passed

Acceptance criteria verified:
- import 'dart:io' — PRESENT
- import 'package:image_picker/image_picker.dart' — PRESENT
- import checklist_image_service — PRESENT
- import checklist_item_image — PRESENT
- final _imageService = ChecklistImageService() — PRESENT
- final Map<String, List<_ChecklistPhotoEntry>> _photosPerItem — PRESENT
- enum _ChecklistPhotoState — PRESENT
- class _ChecklistPhotoEntry — PRESENT
- class _PhotoSourceSheet — PRESENT
- class _ChecklistPhotoStrip — PRESENT
- _imageService.getImagesByExecution(widget.execution.id) — PRESENT
- Future<void> _pickPhoto(String itemId) — PRESENT
- final messenger = ScaffoldMessenger.of(context) — PRESENT (antes do primeiro await)
- if (!mounted) return — PRESENT (multiplas ocorrencias)
- _imageService.uploadImage( — PRESENT
- _PhotoPlaceholder — ABSENT (removido com sucesso)

---
*Phase: 15-photos-per-item*
*Completed: 2026-05-07*
