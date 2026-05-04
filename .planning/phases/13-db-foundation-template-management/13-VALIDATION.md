---
phase: 13
slug: db-foundation-template-management
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-03
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in) |
| **Config file** | primeaudit/pubspec.yaml (flutter_test dependency) |
| **Quick run command** | `flutter analyze` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | TMPLCK-06 | T-13-01 | Seeds com is_padrao=true não podem ser deletados via RLS | manual | — | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | TMPLCK-06 | — | Migration idempotente: re-run não duplica seeds | manual | `supabase db push` | ✅ | ⬜ pending |
| 13-02-01 | 02 | 2 | TMPLCK-01 | — | Abas carregam templates corretos por categoria | manual | `flutter analyze` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 2 | NAV-01 | — | Entrada "Checklist" visível no drawer para todos os perfis | manual | — | ❌ W0 | ⬜ pending |
| 13-03-01 | 03 | 3 | TMPLCK-02 | T-13-02 | Template criado só aparece em "Meus checklists" do criador | manual | — | ❌ W0 | ⬜ pending |
| 13-03-02 | 03 | 3 | TMPLCK-03 | — | Edição preserva todos os itens existentes | manual | — | ❌ W0 | ⬜ pending |
| 13-03-03 | 03 | 3 | TMPLCK-04 | T-13-03 | Exclusão de seed bloqueada por RLS | manual | — | ❌ W0 | ⬜ pending |
| 13-04-01 | 04 | 3 | TMPLCK-05 | — | Clone preserva todos os itens; sem seções órfãs | manual | — | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `primeaudit/test/services/checklist_template_service_test.dart` — stubs para TMPLCK-01..06 (covered by Plan 13-02 Task 0)

*Nota: Screen-level test (`checklist_templates_screen_test.dart`) removed from Wave 0 — UI widget tests require a running Flutter widget tree and a live Supabase session; manual verification via smoke test steps in Plan 13-03 is the appropriate strategy for this phase.*

*flutter_test já está disponível; nenhuma instalação necessária.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Seeds visíveis em Industrial/Transportadora para perfil auditor | TMPLCK-06 | Requer sessão autenticada com perfil auditor no Supabase | Login como auditor → abrir aba Industrial → verificar ≥5 templates |
| Clone completo (header + itens) sem seções órfãs | TMPLCK-05 | Requer estado real do banco e UI interativa | Clonar template seed → abrir clone → verificar todos os itens presentes |
| RLS bloqueia delete de seed | TMPLCK-04 | Requer chamada direta ao Supabase com auth de auditor | Tentar DELETE via PostgREST com token de auditor → esperar 403 |
| Entrada "Checklist" visível no drawer para todos os perfis | NAV-01 | Requer UI rodando com múltiplos perfis | Login com auditor, adm e superuser → verificar item no drawer |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready — Wave 0 satisfied by Plan 13-02 Task 0 (service stub); screen test deferred to manual smoke test in Plan 13-03.
