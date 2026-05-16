---
phase: 21
slug: company-self-registration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-15
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in) |
| **Config file** | none (Flutter default test runner) |
| **Quick run command** | `flutter test test/models/company_test.dart` |
| **Full suite command** | `flutter test` (from `primeaudit/`) |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/company_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-T1 | 01 | 1 | ONBOARD-01 (SC-2, SC-5) | T-role-escalation | Role clamped to auditor/adm in trigger | manual | See Manual-Only | N/A | ⬜ pending |
| 21-02-T1 | 02 | 1 | ONBOARD-01 (SC-5) | — | N/A | unit | `flutter test test/models/company_test.dart` | ✅ (extensão) | ⬜ pending |
| 21-02-T2 | 02 | 1 | ONBOARD-01 (SC-3) | — | N/A | manual | See Manual-Only | N/A | ⬜ pending |
| 21-03-T1 | 03 | 2 | ONBOARD-01 (SC-1, SC-4) | — | N/A | manual | See Manual-Only | N/A | ⬜ pending |
| 21-03-T2 | 03 | 2 | ONBOARD-01 (SC-1, SC-4) | — | N/A | manual + analyze | `dart analyze lib/screens/register_screen.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all automated phase requirements. No new test files required before execution — SC-1, SC-2, SC-3, SC-4 require a live Supabase project and cannot be unit-tested without mocking the RPC layer (which would require new packages, forbidden by CLAUDE.md constraints).

- [x] `test/models/company_test.dart` — already exists, will be extended in 21-02 Task 1

*SC-1, SC-2, SC-3, SC-4 delegated to Manual-Only section below.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration aplicada e colunas existem | ONBOARD-01 (SC-5, SC-2) | Requer Supabase live | Após `supabase db push` ou SQL Editor: `SELECT column_name FROM information_schema.columns WHERE table_name='companies' AND column_name IN ('status','trial_expires_at','license_expires_at');` — deve retornar 3 linhas |
| RPC `create_company_for_registration` funciona via anon | ONBOARD-01 (SC-2) | Requer Supabase live + RPC grant | No SQL Editor: `SELECT create_company_for_registration('12.345.678/0001-99', 'Empresa Teste');` — deve retornar UUID sem erro |
| Empresa criada tem status='trial' e trial_expires_at ~+30d | ONBOARD-01 (SC-2) | Requer DB live | `SELECT id, status, trial_expires_at FROM companies WHERE cnpj='12345678000199' ORDER BY created_at DESC LIMIT 1;` — status='trial', trial_expires_at entre now()+29d e now()+31d |
| Handle_new_user clampeia role a adm | ONBOARD-01 (SC-3) | Requer auth.signUp live | Registrar usuário com role='superuser' no metadata → confirmar que profile.role = 'auditor' (clamped) |
| Fluxo "Criar minha empresa" completo | ONBOARD-01 (SC-1, SC-3) | Widget test requer Supabase mock | No app: RegisterScreen → CNPJ inexistente → "Criar minha empresa" → preencher nome → cadastrar → confirmar HomeScreen ou "verifique email" |
| Fluxo CNPJ encontrado não quebrou | ONBOARD-01 (SC-4) | Widget test requer Supabase mock | No app: RegisterScreen → CNPJ de empresa existente → vinculação automática funciona igual ao anterior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: SC-5 has automated test; SC-1,2,3,4 are manual-only (justified by RPC dependency)
- [x] Wave 0 covers all MISSING references (SC-5 only; others delegated to manual)
- [x] No watch-mode flags
- [x] Feedback latency < 15s for automated path
- [ ] `nyquist_compliant: true` set in frontmatter (set after sign-off)

**Approval:** pending
