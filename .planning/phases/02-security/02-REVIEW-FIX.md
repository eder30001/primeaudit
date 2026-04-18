---
phase: 02-security
fixed_at: 2026-04-18T00:00:00Z
fix_scope: critical_warning
findings_in_scope: 3
fixed: 3
skipped: 0
iteration: 1
status: all_fixed
---

# Phase 02: Code Review Fix Report

## Fixed

### CR-01: PostgREST filter injection in `CompanyService.findByCnpj`
**Fix applied:** Replaced `.or('cnpj.eq.$cnpj,cnpj.eq.$clean')` with a single `.eq('cnpj', clean)` using the already-sanitised digits-only value. Added a length guard (`if (clean.length != 14) return null`) before the network call.
**File:** `primeaudit/lib/services/company_service.dart`
**Commit:** 1e05815

### CR-02: RLS blocks company linkage on new user registration — silent data loss
**Fix applied:** Passed `company_id` in the `signUp` metadata `data` map (`if (companyId != null) 'company_id': companyId`). Removed the post-signup `.update()` block that was blocked by RLS for auditor-role users. Added migration `20260418_handle_new_user_company_id.sql` that updates the `handle_new_user` trigger to read `company_id` from `raw_user_meta_data` during profile INSERT.
**Files:** `primeaudit/lib/services/auth_service.dart`, `primeaudit/supabase/migrations/20260418_handle_new_user_company_id.sql`
**Commit:** 294ac7f

### WR-01: Company lookup swallows network errors silently in `RegisterScreen`
**Fix applied:** Added `_showError('Erro ao buscar empresa. Verifique sua conexão.')` call inside the catch block so network failures surface a visible snackbar instead of failing silently.
**File:** `primeaudit/lib/screens/register_screen.dart`
**Commit:** 3a85d9d

## Skipped

None — all findings in scope were fixed.

---

_Fixed: 2026-04-18_
_Fixer: Claude (gsd-code-fixer)_
_Scope: critical_warning_
