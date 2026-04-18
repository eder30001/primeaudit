---
phase: 02-security
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - primeaudit/supabase/migrations/20260418_fix_active_guard.sql
  - primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql
  - primeaudit/lib/core/cnpj_validator.dart
  - primeaudit/test/core/cnpj_validator_test.dart
  - primeaudit/lib/screens/register_screen.dart
  - primeaudit/lib/screens/admin/company_form.dart
  - primeaudit/SECURITY-AUDIT.md
findings:
  critical: 2
  warning: 1
  info: 1
  total: 4
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-18
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

This phase delivers three security requirements: SEC-01 (RLS coverage for profiles, companies, perimeters, audit_types, audit_templates, template_items), SEC-02 (adm cannot escalate roles), and SEC-03 (inactive users denied via `active = true` guard in SECURITY DEFINER functions). The SQL migrations are structurally sound and the CNPJ validator is correct. Two critical issues were found: a PostgREST filter injection in `CompanyService.findByCnpj` and an RLS gap that silently drops the company linkage on every new user registration.

---

## Critical Issues

### CR-01: PostgREST filter injection in `CompanyService.findByCnpj`

**File:** `primeaudit/lib/services/company_service.dart:72`

**Issue:** The unescaped raw `cnpj` parameter is interpolated directly into the PostgREST `.or()` filter string:

```dart
.or('cnpj.eq.$cnpj,cnpj.eq.$clean')
```

The PostgREST `or()` helper parses its argument as a comma-separated list of filter expressions. If `cnpj` contains a comma (`,`) or parentheses, the server-side parser will split the argument at unexpected points, producing a malformed or attacker-influenced filter. For example, input `11.222.333/0001-81,cnpj.neq.null` would inject an extra condition.

The `clean` variable strips `.-/` but still contains only digits, so it is safe. The raw `cnpj` must not be used in the filter string.

**Fix:** Pass only the already-sanitised `clean` value:

```dart
Future<Company?> findByCnpj(String cnpj) async {
  final clean = cnpj.replaceAll(RegExp(r'[.\-/\s]'), '');
  if (clean.length != 14) return null;           // guard before network call
  final data = await _client
      .from('companies')
      .select()
      .eq('active', true)
      .eq('cnpj', clean)                         // single .eq, no string interpolation
      .maybeSingle();
  return data != null ? Company.fromMap(data) : null;
}
```

This requires that `cnpj` values in the database are stored in the stripped (digits-only) form, which should be enforced at insert/update time (already handled by `CompanyForm._save` which passes `.trim()` without stripping — see CR-02 below for the related normalisation note).

---

### CR-02: RLS blocks company linkage on new user registration — silent data loss

**File:** `primeaudit/lib/services/auth_service.dart:53-57`

**Issue:** After `signUp`, the code updates the new user's `profiles` row to set `company_id`:

```dart
if (response.user != null && companyId != null) {
  await _client
      .from('profiles')
      .update({'company_id': companyId})
      .eq('id', response.user!.id);
}
```

The new RLS migration (`20260418_rls_profiles_companies_perimeters.sql`) defines the following UPDATE policies on `profiles`:

- `superuser_dev_profiles_full` — UPDATE allowed only for superuser/dev role
- `adm_profiles_update` — UPDATE allowed only for adm role

There is no policy that allows a newly registered user (role = `auditor` or empty/null at creation time) to update their own profile. `user_select_own` is SELECT-only. As a result, the `.update()` call is blocked by RLS, PostgREST returns `0 rows updated` (not an exception), and the `company_id` linkage is silently dropped. The user is registered without a company association, violating the intent of the registration flow and the **Core Value** (no silent data loss of field-submitted data).

**Fix (option A — preferred):** Move company assignment into the `signUp` call's `data` metadata and handle it via a database trigger on `profiles` INSERT, or use a Supabase Edge Function. This avoids the RLS gap entirely.

**Fix (option B — minimal):** Add a scoped UPDATE policy to the migration so a freshly authenticated user can update their own `company_id` once, but only if it is currently NULL:

```sql
-- Allow a user to link themselves to a company once (company_id must be NULL initially)
CREATE POLICY "user_link_own_company" ON profiles FOR UPDATE
  USING  (id = auth.uid() AND get_my_role() IS NOT NULL AND company_id IS NULL)
  WITH CHECK (id = auth.uid() AND get_my_role() IS NOT NULL AND company_id IS NOT NULL);
```

**Fix (option C — minimal, no new migration):** Pass `company_id` in the `signUp` metadata so it is set by the trigger/function that creates the profile row, eliminating the post-signup UPDATE entirely:

```dart
final response = await _client.auth.signUp(
  email: email,
  password: password,
  data: {'full_name': name, 'company_id': companyId},
);
// Remove the follow-up .update() block
```

This only works if the profile-creation trigger reads `company_id` from `raw_user_meta_data`.

---

## Warnings

### WR-01: Company lookup swallows network errors silently in `RegisterScreen`

**File:** `primeaudit/lib/screens/register_screen.dart:68-70`

**Issue:** The catch block in `_searchCompany` sets `_cnpjNotFound = false` and returns without any user feedback:

```dart
} catch (_) {
  if (mounted) setState(() => _cnpjNotFound = false);
}
```

A network failure is silently treated as "no search performed". The user types a valid CNPJ, sees neither the green check (company found) nor the red cross (not found), and has no way to know whether the lookup succeeded or failed. If they proceed to register, the company linkage is omitted without warning.

**Fix:** Distinguish the error state from the "not searched" state and surface a brief snackbar:

```dart
} catch (_) {
  if (mounted) {
    setState(() => _cnpjNotFound = false);
    _showError('Erro ao buscar empresa. Verifique sua conexão.');
  }
}
```

---

## Info

### IN-01: CNPJ stored in raw (formatted) form may break lookup in `findByCnpj`

**File:** `primeaudit/lib/services/company_service.dart:67-68`

**Issue:** `findByCnpj` searches for both the formatted and stripped form of the CNPJ using `.or(...)`. After the fix for CR-01, the query will use only the stripped `clean` form. However, `CompanyForm._save` (line 61-63 of `company_form.dart`) stores the CNPJ as-is from `_cnpjController.text.trim()`, which may preserve the user-typed formatting (`11.222.333/0001-81`). If the stored value is formatted but the lookup queries the stripped form, lookups will return no results.

**Fix:** Normalise the CNPJ to digits-only before storing it:

```dart
'cnpj': _cnpjController.text.trim().isEmpty
    ? null
    : _cnpjController.text.replaceAll(RegExp(r'[.\-/\s]'), ''),
```

---

_Reviewed: 2026-04-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
