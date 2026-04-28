---
phase: 09-images
plan: 02
subsystem: services
tags: [supabase, storage, image_picker, flutter, dart, model, service]

# Dependency graph
requires:
  - phase: 09-01
    provides: "Tabela audit_item_images + bucket audit-images + image_picker no pubspec"
provides:
  - "AuditItemImage — modelo tipado da tabela audit_item_images com fromMap factory"
  - "ImageService — 4 métodos públicos: uploadImage, getImages, getSignedUrl, deleteImage"
affects: [09-03, AuditExecutionScreen, _ImageStrip, _ThumbTile]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "UUID v4 gerado no cliente com dart:math Random.secure — sem package externo (uuid)"
    - "uploadBinary + XFile.readAsBytes — upload multiplataforma sem File do dart:io"
    - "Storage delete best-effort (try/catch) + DB delete propagando erro — contratos assimétricos de erro intencionais"
    - "getImages usa .order('created_at') sem ascending: true — PostgREST default ASC"

key-files:
  created:
    - "primeaudit/lib/models/audit_item_image.dart"
    - "primeaudit/lib/services/image_service.dart"
  modified: []

key-decisions:
  - "uploadImage retorna AuditItemImage (não void) — caller (_ImageStrip) usa o objeto para transicionar para estado uploaded com storagePath real"
  - "deleteImage: Storage remove com try/catch (best-effort) para resiliência a objetos já deletados; DB delete sem try/catch para que caller gerencie retry"
  - "UUID v4 com dart:math — evitar adição de package uuid; 16 bytes Random.secure garante suficiente entropia"
  - "Sem try/catch em uploadImage — falha de rede/Storage deve propagar ao _ImageStrip que gerencia estado de erro sem bloquear _saveAnswer (core value)"

requirements-completed: [IMG-02, IMG-03]

# Metrics
duration: ~5min
completed: 2026-04-28
---

# Phase 09 Plan 02: AuditItemImage Model + ImageService Summary

**Modelo `AuditItemImage` (7 campos tipados, `fromMap` factory) e `ImageService` (4 métodos públicos: uploadImage, getImages, getSignedUrl, deleteImage) — contrato de serviço completo para upload/exibição/deleção de fotos em itens de auditoria**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-28T23:51:16Z
- **Completed:** 2026-04-28T23:56:08Z
- **Tasks:** 2/2 concluídas
- **Files created:** 2

## Accomplishments

- `AuditItemImage` model: 7 campos (id, auditId, templateItemId, companyId, storagePath, createdBy, createdAt), `const` constructor, `factory fromMap` com cast explícito — Dart puro (sem flutter/material import)
- `ImageService.uploadImage`: XFile → readAsBytes → Storage.uploadBinary (path `{companyId}/{auditId}/{itemId}/{uuid}.jpg`) → INSERT audit_item_images → retorna AuditItemImage
- `ImageService.getImages`: SELECT filtrado por audit_id + template_item_id, ordenado por created_at ASC
- `ImageService.getSignedUrl`: createSignedUrl com expiração 3600s
- `ImageService.deleteImage`: Storage.remove best-effort (try/catch) + DELETE tabela (propaga erro)
- UUID v4 gerado internamente com `dart:math Random.secure` — sem dependência externa

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | AuditItemImage model | `0846373` | `primeaudit/lib/models/audit_item_image.dart` |
| 2 | ImageService | `7838d3e` | `primeaudit/lib/services/image_service.dart` |

## Method Signatures (referência para Wave 3 — 09-03)

```dart
// AuditItemImage — primeaudit/lib/models/audit_item_image.dart
class AuditItemImage {
  final String id;
  final String auditId;
  final String templateItemId;
  final String companyId;
  final String storagePath;
  final String createdBy;
  final DateTime createdAt;

  const AuditItemImage({ required String id, required String auditId,
    required String templateItemId, required String companyId,
    required String storagePath, required String createdBy,
    required DateTime createdAt });
  factory AuditItemImage.fromMap(Map<String, dynamic> map);
}

// ImageService — primeaudit/lib/services/image_service.dart
class ImageService {
  Future<AuditItemImage> uploadImage({
    required String companyId,
    required String auditId,
    required String itemId,
    required XFile file,
  });

  Future<List<AuditItemImage>> getImages({
    required String auditId,
    required String itemId,
  });

  Future<String> getSignedUrl(String storagePath);

  Future<void> deleteImage({
    required String imageId,
    required String storagePath,
  });
}
```

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `primeaudit/lib/models/audit_item_image.dart` | 37 | Modelo tipado da tabela audit_item_images |
| `primeaudit/lib/services/image_service.dart` | 103 | CRUD de imagens no Storage + tabela |

## Deviations from Plan

None — plano executado exatamente como escrito. Implementação corresponde ponto a ponto à especificação do plano, incluindo o contrato assimétrico de erros em deleteImage.

## Threat Model Compliance

| Threat | Disposition | Implementation |
|--------|------------|----------------|
| T-09-06: storagePath em deleteImage | mitigate | storagePath recebido da lista de AuditItemImage carregada do banco — nunca aceita path arbitrário de entrada do usuário |
| T-09-07: signed URL expõe conteúdo | accept | Expira em 3600s; acesso apenas para usuário autenticado da mesma empresa via RLS |
| T-09-08: upload de arquivo não-JPEG | mitigate | `contentType: 'image/jpeg'` no FileOptions + image_picker filtra imagens no caller |
| T-09-09: DoS por imagem grande | mitigate | Compressão no caller (_ImageStrip) via ImagePicker(imageQuality: 85, maxWidth: 1200) |

## Self-Check: PASSED

- FOUND: `primeaudit/lib/models/audit_item_image.dart`
- FOUND: `primeaudit/lib/services/image_service.dart`
- FOUND: commit 0846373 (Task 1 — AuditItemImage model)
- FOUND: commit 7838d3e (Task 2 — ImageService)
- flutter analyze: No issues found! (2 arquivos)

---
*Phase: 09-images*
*Completed: 2026-04-28*
