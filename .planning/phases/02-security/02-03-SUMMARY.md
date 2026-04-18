---
plan: 02-03
phase: 02-security
status: complete
completed: 2026-04-18
---

## Summary

Implemented pure Dart CNPJ checksum validator (SEC-04) with 16 unit tests, wired to both CNPJ form fields in `register_screen.dart` and `company_form.dart`.

## What Was Built

**`primeaudit/lib/core/cnpj_validator.dart`** — Pure Dart utility with two top-level functions:
- `isValidCnpj(String)` — implements Receita Federal algorithm (weights w1/w2), rejects same-digit sequences and invalid check digits
- `validateCnpj(String?)` — TextFormField.validator-compatible wrapper; returns null for empty/null input (optional field per D-03)

**`primeaudit/test/core/cnpj_validator_test.dart`** — 16 test cases covering: 3 valid CNPJs (formatted + raw), 2 invalid checksums, 2 same-digit rejections, 2 length errors, 1 non-digit, 3 optional-field nulls, 1 valid via validateCnpj, 1 length error via validateCnpj, 1 checksum error via validateCnpj.

**`primeaudit/lib/screens/register_screen.dart`** — Added import + `validator: validateCnpj` to CNPJ TextFormField (line 312). `onChanged: _searchCompany` preserved.

**`primeaudit/lib/screens/admin/company_form.dart`** — Added import + `validator: validateCnpj` to CNPJ `_buildField` call (line 144). No other fields touched.

## Key Files

### Created
- `primeaudit/lib/core/cnpj_validator.dart`
- `primeaudit/test/core/cnpj_validator_test.dart`

### Modified
- `primeaudit/lib/screens/register_screen.dart` (import + validator line)
- `primeaudit/lib/screens/admin/company_form.dart` (import + validator param)

## Self-Check: PASSED

- [x] `isValidCnpj` and `validateCnpj` are pure top-level functions (no class, no Flutter/Supabase imports)
- [x] 16 unit tests, all passing (`flutter test test/core/cnpj_validator_test.dart` — 16/16)
- [x] Both CNPJ fields wired with `validator: validateCnpj` (exactly 1 per file)
- [x] `onChanged: _searchCompany` preserved in register_screen
- [x] `flutter analyze` — no issues on 3 changed files
- [x] Full suite `flutter test` — 25/25 passed (no regressions in Phase 1 tests)
