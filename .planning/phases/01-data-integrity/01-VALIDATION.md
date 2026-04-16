---
phase: 1
slug: data-integrity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK built-in) |
| **Config file** | none — `flutter test` discovers `test/` directory automatically |
| **Quick run command** | `cd primeaudit && flutter test test/` |
| **Full suite command** | `cd primeaudit && flutter test test/` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd primeaudit && flutter test test/`
- **After every plan wave:** Run `cd primeaudit && flutter test test/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | DINT-01, DINT-02, DINT-03 | — | N/A | Wave 0 setup | `cd primeaudit && flutter test test/audit_execution_save_error_test.dart` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 0 | D-06, Backoff | — | N/A | Wave 0 setup | `cd primeaudit && flutter test test/pending_save_test.dart` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | DINT-01 | — | N/A | Widget test | `cd primeaudit && flutter test test/audit_execution_save_error_test.dart` | ✅ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | DINT-02 | — | N/A | Widget test | `cd primeaudit && flutter test test/audit_execution_save_error_test.dart` | ✅ W0 | ⬜ pending |
| 1-02-03 | 02 | 1 | DINT-03 | — | N/A | Widget test | `cd primeaudit && flutter test test/audit_execution_save_error_test.dart` | ✅ W0 | ⬜ pending |
| 1-03-01 | 03 | 1 | D-06 | — | N/A | Widget test | `cd primeaudit && flutter test test/audit_execution_save_error_test.dart` | ✅ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `primeaudit/test/audit_execution_save_error_test.dart` — covers DINT-01, DINT-02, DINT-03, D-06
- [ ] `primeaudit/test/pending_save_test.dart` — covers `_PendingSave` unit behavior and backoff logic
- No framework install needed — `flutter_test` is already a dev dependency

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SnackBar visually appears and is dismissible | DINT-01 | Visual verification | Run app, simulate network failure, confirm snackbar with "Tentar novamente" appears |
| Auto-retry silently re-saves after ~1s | DINT-03 | Timing-dependent async | Run app, disable network, tap answer, re-enable, verify item saves after ~1s delay |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
