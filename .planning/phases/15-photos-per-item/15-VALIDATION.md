---
phase: 15
slug: photos-per-item
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-07
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK — sem instalação adicional) |
| **Config file** | none — `flutter test` executa por convenção |
| **Quick run command** | `flutter test test/checklist_photo_isolation_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/checklist_photo_isolation_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 0 | EXEC-04 | T-15-01 | Auditor acessa apenas imagens de suas próprias execuções (RLS Pattern 3) | unit (stub) | `flutter test test/checklist_image_service_test.dart` | ❌ W0 | ⬜ pending |
| 15-01-02 | 01 | 0 | EXEC-04 | — | Upload retorna ChecklistItemImage com storagePath no formato correto | unit (stub) | `flutter test test/checklist_image_service_test.dart` | ❌ W0 | ⬜ pending |
| 15-02-01 | 02 | 1 | EXEC-04 | — | Modelo ChecklistItemImage.fromMap parseia todos os campos corretamente | unit | `flutter test test/checklist_item_image_test.dart` | ❌ W0 | ⬜ pending |
| 15-03-01 | 03 | 2 | EXEC-04 / SC-3 | — | Falha de upload não adiciona item a _failedSaves; _finalize não bloqueia | widget test | `flutter test test/checklist_photo_isolation_test.dart` | ❌ W0 | ⬜ pending |
| 15-03-02 | 03 | 2 | EXEC-04 / SC-1 | — | _ChecklistPhotoStrip renderiza botão câmera e miniaturas com estados diferentes | widget test | `flutter test test/checklist_photo_strip_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/checklist_image_service_test.dart` — stubs para EXEC-04 upload, getImages, deleteImage
- [ ] `test/checklist_item_image_test.dart` — unit test de ChecklistItemImage.fromMap
- [ ] `test/checklist_photo_isolation_test.dart` — verifica que falha de upload não entra em _failedSaves e não bloqueia _finalize
- [ ] `test/checklist_photo_strip_test.dart` — widget test do _ChecklistPhotoStrip com fotos em estados uploading/uploaded/error

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Câmera e galeria abrem e retornam foto | EXEC-04 / SC-1 | Requer dispositivo físico ou emulador com câmera | No emulador Android: abrir execução de checklist com item tipo 'photo', tocar câmera, tirar foto; verificar miniatura inline |
| Múltiplas fotos por item visíveis | EXEC-04 / SC-2 | Requer interação UI real com Storage real | Adicionar 3 fotos a um item; verificar que strip horizontal exibe 3 miniaturas com scroll |
| Falha de upload mostra snackbar sem bloquear | SC-3 | Requer simulação de falha de rede real | Desligar WiFi, tentar upload de foto; verificar snackbar de erro; preencher mais respostas e finalizar checklist normalmente |
| Foto carrega ao reabrir rascunho | EXEC-04 | Requer Storage real com signed URLs | Fechar app após upload; reabrir execução rascunho; verificar que miniatura aparece |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
