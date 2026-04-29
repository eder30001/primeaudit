---
phase: 09-images
plan: 03
subsystem: ui
tags: [flutter, image_picker, supabase-storage, audit-execution, material3]

# Dependency graph
requires:
  - phase: 09-01
    provides: "Tabela audit_item_images + bucket audit-images + image_picker no pubspec"
  - phase: 09-02
    provides: "ImageService (uploadImage/getImages/getSignedUrl/deleteImage) + AuditItemImage model"
provides:
  - "_ImageStrip StatefulWidget (camera button + thumbnail strip + upload state machine)"
  - "_ThumbTile com 3 estados visuais: uploading spinner, uploaded+remove badge, error+retry"
  - "_PickerSheet bottom sheet ('Tirar foto' / 'Escolher da galeria')"
  - "Fullscreen viewer via Dialog.fullscreen + InteractiveViewer"
  - "Propagation chain: _AuditExecutionScreenState → _SectionBlock → _ItemCard → _ImageStrip"
  - "_load() carrega imagens existentes por item em bloco resiliente (try/catch isolado)"
affects: [audit-execution, AuditExecutionScreen, 09-04-verify]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_UploadState enum (uploading/uploaded/error) + _UploadEntry classe para state machine de upload"
    - "Carregamento em paralelo com Future.wait + try/catch isolado (resilência core value: falha de imagem não bloqueia checklist)"
    - "Remoção otimista de imagem (setState antes do deleteImage, reverter em caso de erro)"
    - "_ThumbTile instancia _imageService como field (convenção CLAUDE.md — não recebe via construtor)"
    - "Tooltip wrapping GestureDetector para botão câmera (acessibilidade)"

key-files:
  created: []
  modified:
    - "primeaudit/lib/screens/audit_execution_screen.dart"

key-decisions:
  - "Todos os widgets de imagem (3 classes) adicionados no final do mesmo arquivo audit_execution_screen.dart — self-contained, sem criar novos arquivos de tela"
  - "_ThumbTile carrega signedUrl via initState + _loadSignedUrl() independentemente — cada tile faz sua própria chamada de rede"
  - "Fullscreen viewer usa Dialog.fullscreen (Material 3) — modal overlay sem navegação de tela"
  - "Remoção sem confirmação — baixo risco durante auditoria ativa (per UI-SPEC)"
  - "SizedBox(height: 8) inserido antes do _ImageStrip para respeitar espaçamento do _ItemCard"

patterns-established:
  - "_UploadEntry state machine pattern: tempKey → uploaded key transition via setState atomics"
  - "Propagation chain via 3 camadas: tela pai passa Map<itemId, images> → bloco de seção → card de item → widget de images"

requirements-completed: [IMG-01, IMG-02, IMG-03]

# Metrics
duration: ~30min
completed: 2026-04-29
---

# Phase 09 Plan 03: AuditExecutionScreen — UI de imagens por item Summary

**_ImageStrip com camera picker + estados uploading/uploaded/error, fullscreen viewer InteractiveViewer, e carga de imagens existentes resiliente em _load() — sistema completo de foto por pergunta no audit_execution_screen.dart**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-04-29T00:00:00Z
- **Completed:** 2026-04-29T00:02:14Z
- **Tasks:** 2/3 completas (Task 3 = checkpoint humano — aguardando verificação)
- **Files modified:** 1

## Accomplishments

- `_UploadState` enum (3 valores) e `_UploadEntry` classe adicionados antes da classe principal
- `_ImageStrip` StatefulWidget (linhas 1657–1897): câmera button 44dp, picker modal, upload flow com tempKey→id transition, retry, remoção otimista
- `_ThumbTile` StatefulWidget (linhas 1899–2077): 3 estados visuais conforme UI-SPEC — uploading (spinner overlay 24dp), uploaded (Image.network + remove badge 20dp visual / 44dp tap), error (error_rounded icon, GestureDetector retry)
- `_PickerSheet` StatelessWidget (linhas 2079–2103): 'Tirar foto' / 'Escolher da galeria' com ListTile e ícones accent
- Fullscreen viewer via `Dialog.fullscreen` + `InteractiveViewer` + close button `Icons.close_rounded`
- `_AuditExecutionScreenState._load()` ampliado: `Future.wait` para imagens em bloco try/catch isolado — falha de rede não impede abertura do checklist (core value)
- Cadeia de propagação completa: `_AuditExecutionScreenState._images[itemId]` → `_SectionBlock` → `_ItemCard` → `_ImageStrip`
- `flutter analyze` limpo: "No issues found!"

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | _ImageStrip, _ThumbTile, _PickerSheet + fullscreen viewer widgets | `babe157` | `primeaudit/lib/screens/audit_execution_screen.dart` |
| 2 | Propagar images para _ItemCard + carregar imagens no _load() | `a3f20b9` | `primeaudit/lib/screens/audit_execution_screen.dart` |
| 3 | Verificação humana (checkpoint) | PENDENTE | — |

## Files Created/Modified

| File | Lines | Modificação |
|------|-------|-------------|
| `primeaudit/lib/screens/audit_execution_screen.dart` | 2104 (+528) | Imports adicionados, _UploadState/_UploadEntry, _images/_imageService no state, _load() ampliado, _SectionBlock+_ItemCard com 3 novos params, _ImageStrip/_ThumbTile/_PickerSheet no final |

## Widget Line Ranges (audit_execution_screen.dart)

- `_ImageStrip` StatefulWidget + State: linhas 1657–1897
- `_ThumbTile` StatefulWidget + State: linhas 1899–2077
- `_PickerSheet` StatelessWidget: linhas 2079–2103

## Propagation Chain Implemented

```
_AuditExecutionScreenState
  ._images: Map<String, List<AuditItemImage>>   ← carregado em _load()
  ↓ images: _images, onImagesChanged: setState, companyId: CompanyContextService
_SectionBlock
  ↓ images: images[item.id] ?? [], onImagesChanged: onImagesChanged(item.id, ...), companyId
_ItemCard (build)
  ├── ... (existing widgets)
  ├── GestureDetector (observation toggle)   [existing]
  ├── SizedBox(height: 8)                    [NEW]
  ├── _ImageStrip(...)                       [NEW — Phase 9]
  └── if (onCreateAction != null ...) ...   [existing]
_ImageStrip
  └── gerencia _entries: Map<String, _UploadEntry>
```

## Decisions Made

- Todos os 3 widgets privados no final do arquivo existente — não criar novos arquivos (self-contained approach do plano)
- `Dialog.fullscreen` usado para fullscreen viewer (Material 3 idiomático)
- `_ThumbTile` instancia `_imageService` como field (não recebe via construtor) — convenção CLAUDE.md
- `imageQuality: 85` + `maxWidth: 1200` na chamada do ImagePicker — controle de tamanho no cliente

## Deviations from Plan

None — plano executado exatamente como escrito. Todos os copywriting contracts, dimensões e layouts seguiram a UI-SPEC rigorosamente.

## Threat Model Compliance

| Threat | Disposition | Status |
|--------|-------------|--------|
| T-09-10: companyId via CompanyContextService | mitigate | companyId vem de `CompanyContextService.instance.activeCompanyId ?? ''` — singleton autorizado, não input do usuário |
| T-09-11: signed URL expirada | accept | Aceitável — Image.network mostra erro de carregamento; usuário fecha e reabre |
| T-09-12: signedUrl em memória | accept | URL efêmera (1h), não persistida em disco |
| T-09-13: _load() carrega imagens de outros itens | mitigate | getImages() filtra por auditId AND templateItemId |

## Known Stubs

Nenhum — sistema totalmente wired: botão câmera → ImagePicker → ImageService.uploadImage → AuditItemImage → _images state → UI. Dados do banco carregados em _load() via ImageService.getImages().

## Human Verify Result

PENDENTE — Task 3 é checkpoint humano (`type="checkpoint:human-verify"`). Verificação manual necessária antes de marcar o plano como completo.

## Next Phase Readiness

- **Código pronto:** Os widgets estão implementados e `flutter analyze` está limpo
- **Verificação necessária:** Testar fluxo real no app (câmera, galeria, upload, fullscreen, remover, read-only)
- **Dependência crítica:** Migration `20260427_create_audit_item_images.sql` deve estar aplicada ao banco Supabase para que uploads funcionem
- **Referência:** Ver instruções de aplicação da migration em `09-01-SUMMARY.md > User Setup Required`

## Self-Check: PASSED

- FOUND: `primeaudit/lib/screens/audit_execution_screen.dart` (2104 linhas)
- FOUND: `class _ImageStrip extends StatefulWidget` (linha 1657)
- FOUND: `class _ThumbTile extends StatefulWidget` (linha 1899)
- FOUND: `class _PickerSheet extends StatelessWidget` (linha 2079)
- FOUND: commit babe157 (Task 1)
- FOUND: commit a3f20b9 (Task 2)
- flutter analyze: "No issues found!"

---
*Phase: 09-images*
*Completed: 2026-04-29*
