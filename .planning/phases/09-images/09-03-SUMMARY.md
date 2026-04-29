---
phase: 09-images
plan: 03
status: complete
subsystem: ui
tags: [flutter, image_picker, supabase-storage, corrective-actions, material3]

requirements-completed: [IMG-01, IMG-02, IMG-03]
completed: 2026-04-29
---

# Phase 09 Plan 03: UI de imagens + ações corretivas por item — Summary

**Câmera integrada ao CreateCorrectiveActionScreen, ações corretivas exibidas por item no checklist, fotos vinculadas à ação específica, e galeria no detalhe da ação.**

## Commits

| Commit | Descrição |
|--------|-----------|
| `babe157` | add _ImageStrip, _ThumbTile, _PickerSheet + fullscreen viewer (iteração inicial) |
| `a3f20b9` | propagate images to _ItemCard + load existing images in _load() |
| `c4df8c6` | fix: camera only on non-conforming + didUpdateWidget signed URL + finalize alert |
| `bfc5d29` | fix: move camera to CreateCorrectiveActionScreen + clean up execution screen |
| `9bd2814` | feat: show corrective actions per item in execution + photos in detail screen |
| `8a28b4b` | fix: link images to specific corrective action (corrective_action_id) |

## O que foi entregue

### CreateCorrectiveActionScreen — seção de fotos
- Botão câmera (44dp, accent) + bottom sheet "Tirar foto" / "Escolher da galeria"
- Upload imediato ao selecionar; miniatura 72x72dp com estado uploading/uploaded/error
- Retry por toque na miniatura de erro; remoção via botão x
- Após criar ação: `linkImagesToAction()` vincula fotos ao `corrective_action_id` específico

### AuditExecutionScreen — ações por item
- `_ActionRow` widget: ponto colorido + título truncado + label de status + chevron
- Ações carregadas em `_load()` via `getActionsByAudit()`, agrupadas por `templateItemId`
- "Criar ação corretiva" -> "Adicionar ação corretiva" quando já existe ao menos uma
- Reload automático ao retornar de criar/detalhar ação
- Alerta ao finalizar auditoria com itens não-conformes sem ação cadastrada

### CorrectiveActionDetailScreen — galeria de fotos
- Card "FOTOS DA NAO CONFORMIDADE" com miniaturas 80x80dp
- Filtra imagens por `corrective_action_id = action.id` — cada ação vê apenas suas fotos
- Toque abre fullscreen viewer (Dialog.fullscreen + InteractiveViewer)

### Modelo e serviços
- `AuditItemImage`: campo `correctiveActionId` nullable adicionado
- `CorrectiveActionService.createAction()`: retorna `String` (ID criado) em vez de void
- `ImageService.getImages()`: parâmetro opcional `correctiveActionId` para filtragem
- `ImageService.linkImagesToAction()`: UPDATE em lote para vincular fotos a uma ação
- Storage RLS: simplificada para `bucket_id = 'audit-images'` (autenticados)

## Files Modified

| File | Papel |
|------|-------|
| `primeaudit/lib/screens/audit_execution_screen.dart` | _ActionRow, _reloadItemActions, _openActionDetail, alerta ao finalizar |
| `primeaudit/lib/screens/create_corrective_action_screen.dart` | Secao de fotos + linkImagesToAction apos criar acao |
| `primeaudit/lib/screens/corrective_action_detail_screen.dart` | Galeria de fotos + fullscreen viewer |
| `primeaudit/lib/services/corrective_action_service.dart` | createAction->String, getActionsByAudit, getItemIdsWithActions |
| `primeaudit/lib/services/image_service.dart` | getImages com filtro opcional + linkImagesToAction |
| `primeaudit/lib/models/audit_item_image.dart` | Campo correctiveActionId nullable |

## Self-Check: PASSED

- FOUND: `_ActionRow` em `audit_execution_screen.dart`
- FOUND: `_buildPhotoSection` em `create_corrective_action_screen.dart`
- FOUND: `_buildPhotoCard` em `corrective_action_detail_screen.dart`
- FOUND: `linkImagesToAction` em `image_service.dart`
- FOUND: `createAction` retornando `String` em `corrective_action_service.dart`
- flutter analyze: apenas infos pre-existentes
