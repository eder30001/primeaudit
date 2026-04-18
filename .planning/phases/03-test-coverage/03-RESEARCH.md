# Phase 3: Test Coverage - Research

**Researched:** 2026-04-18
**Domain:** Flutter unit testing — pure Dart logic (no Supabase dependency)
**Confidence:** HIGH

## Summary

Phase 3 adds unit tests for the four critical business-logic components identified in QUAL-01 through QUAL-04: `AuditAnswerService.calculateConformity()`, `AppRole` permission helpers, `fromMap()` factories for 6 models (NOT 7 — `UserProfile` does not exist; the model is `AppUser`), and `Perimeter.buildTree()`. All target components are pure Dart — none requires Supabase to be initialized, so every test in this phase will be a standard `test()` (not `testWidgets`) with no mocking needed.

The test suite already passes cleanly (`flutter test` reports `+25 ~2: All tests passed!`). The broken counter scaffold mentioned in the roadmap was already replaced in Phase 1 with a smoke test that just verifies `1 + 1 == 2`. The only work this phase requires is writing four new test files.

**CRITICAL discrepancy:** The roadmap success criterion #3 lists `canEdit` as a method to cover in `AppRole`. That method does not exist anywhere in the codebase — `app_roles.dart` has `canAccessAdmin`, `canAccessDev`, and `isSuperOrDev`. The plan must test the methods that actually exist and note the discrepancy rather than create a method that does not belong to the current design.

**CRITICAL discrepancy:** The roadmap success criterion #4 lists `UserProfile` as one of 7 models. That class does not exist — the model for profiles is `AppUser` (in `primeaudit/lib/models/app_user.dart`). The plan must target `AppUser`.

**Primary recommendation:** Write four test files — one per requirement — each using only `test()` and `group()` from `flutter_test`. No mocks, no Supabase, no `testWidgets`. All targets are pure Dart functions.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUAL-01 | `AuditAnswerService.calculateConformity()` coberto por testes com todos os tipos de resposta e pesos | Pure function — no Supabase dep; directly instantiable via `TemplateItem` constructor |
| QUAL-02 | `AppRole` helpers cobertos para cada role | Static methods — zero setup needed; all 5 roles testable with string constants |
| QUAL-03 | `fromMap()` de todos os models cobertos | Plain factory constructors; maps can be constructed inline in tests |
| QUAL-04 | `Perimeter.buildTree()` coberto com hierarquias profundas | Static method on plain Dart class; no dependencies |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Unit tests for pure logic | Test runner (flutter_test) | — | No UI, no Supabase; dart VM test runner suffices |
| Model deserialization | Models layer | — | fromMap() lives in models, tested in isolation |
| Permission logic | Core layer (AppRole) | — | Static helpers, no state |
| Conformity calculation | Services layer | — | Pure function inside AuditAnswerService, no _client usage |
| Tree construction | Models layer | — | Static method on Perimeter, no external deps |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_test` | SDK (Flutter 3.38.4) | Test runner, assertions, matchers | Built into Flutter SDK — no extra install |

### Supporting

No additional test packages are needed or should be added. [VERIFIED: pubspec.yaml inspection — only `flutter_test` and `flutter_lints` are dev dependencies]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `flutter_test` (built-in) | `test` package directly | No benefit — `flutter_test` already wraps `test` and is already declared |
| Pure `test()` calls | `mockito` or `mocktail` | These would be needed for Supabase mocking; none of the Phase 3 targets need a mock |

**Installation:** No additional packages required. [VERIFIED: all targets are pure Dart — no Supabase.instance.client calls in the tested code paths]

## Architecture Patterns

### System Architecture Diagram

```
[Test File]
    |
    +--> import target class (direct, no DI needed)
    |
    +--> [test()] calls target function/constructor with literal inputs
    |
    +--> [expect()] asserts output matches fixture
```

### Recommended Project Structure

```
primeaudit/test/
├── widget_test.dart             # Existing smoke test — leave as-is
├── pending_save_test.dart       # Existing — Phase 1 work
├── audit_execution_save_error_test.dart  # Existing — Phase 1 work
├── core/
│   └── cnpj_validator_test.dart # Existing — Phase 2 work
├── services/
│   └── audit_answer_service_test.dart   # NEW — QUAL-01
└── models/
    ├── app_role_test.dart               # NEW — QUAL-02 (AppRole is in lib/core/ but test can live here)
    ├── audit_test.dart                  # NEW — QUAL-03 (Audit.fromMap)
    ├── audit_answer_test.dart           # NEW — QUAL-03 (AuditAnswer.fromMap)
    ├── audit_template_test.dart         # NEW — QUAL-03 (AuditTemplate + TemplateItem fromMap)
    ├── perimeter_test.dart              # NEW — QUAL-03 (Perimeter.fromMap) + QUAL-04 (buildTree)
    ├── company_test.dart                # NEW — QUAL-03 (Company.fromMap)
    └── app_user_test.dart               # NEW — QUAL-03 (AppUser.fromMap)
```

Note: `app_role_test.dart` could also live in `test/core/` — either location works. Grouping with models is acceptable since `AppRole` has no UI or service logic.

### Pattern 1: Pure Unit Test (no widget, no Supabase)

**What:** Import the target class directly and call it with constructed inputs.
**When to use:** For all Phase 3 targets — they are all pure Dart with no platform dependencies.

```dart
// Source: existing pattern in primeaudit/test/core/cnpj_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/audit_answer_service.dart';
import 'package:primeaudit/models/audit_template.dart';

void main() {
  group('AuditAnswerService.calculateConformity', () {
    final svc = AuditAnswerService();

    test('empty list returns 100.0', () {
      expect(svc.calculateConformity([], {}), equals(100.0));
    });
  });
}
```

### Pattern 2: fromMap() test with inline fixture map

**What:** Construct a `Map<String, dynamic>` literal and assert field values on the returned model.
**When to use:** For all `fromMap()` tests in QUAL-03.

```dart
// Source: verified by reading primeaudit/lib/models/company.dart
test('Company.fromMap parses required fields', () {
  final map = {
    'id': 'c1',
    'name': 'Acme',
    'active': true,
    'requires_perimeter': false,
    'created_at': '2024-01-01T00:00:00.000Z',
  };
  final company = Company.fromMap(map);
  expect(company.id, equals('c1'));
  expect(company.name, equals('Acme'));
  expect(company.requiresPerimeter, isFalse);
});
```

### Pattern 3: Static method test with constructed object list

**What:** Build a flat `List<Perimeter>` with explicit parent/child relationships and assert tree shape.
**When to use:** `Perimeter.buildTree()` tests for QUAL-04.

```dart
// Source: verified by reading primeaudit/lib/models/perimeter.dart
Perimeter _makePerimeter(String id, {String? parentId}) => Perimeter(
  id: id,
  companyId: 'co1',
  parentId: parentId,
  name: id,
  active: true,
  createdAt: DateTime(2024),
);

test('buildTree: 1-level — single root, no children', () {
  final roots = Perimeter.buildTree([_makePerimeter('root')]);
  expect(roots.length, equals(1));
  expect(roots.first.children, isEmpty);
});
```

### Anti-Patterns to Avoid

- **Calling `Supabase.instance.client` inside a test:** None of the Phase 3 targets use `_client` — but `AuditAnswerService` does have `_client` as a field. Instantiating `AuditAnswerService()` in a test is safe because `calculateConformity` is a pure method; the `_client` field is lazy and not accessed. If Flutter throws `StateError: Supabase not initialized`, wrap with `TestWidgetsFlutterBinding.ensureInitialized()` — but this should not be needed.
- **Using `testWidgets` for pure functions:** Adds unnecessary overhead; `test()` is sufficient and faster.
- **Importing `package:flutter/material.dart` unnecessarily:** Models in this phase import `flutter/material.dart` only where `Color`/`IconData` are used (`AppUser`, `Audit`). Tests do not need to render widgets; the import is still valid but adds compile weight.
- **Testing private helpers through public API instead of directly:** `AuditStatus._statusFromString` is private but exercised via `Audit.fromMap(map['status'] = 'em_andamento')` — test through the public factory.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Assertions | Custom matcher functions | `expect()` + `flutter_test` matchers (`equals`, `isNull`, `isEmpty`, `closeTo`) | Built-in matchers are composable and produce clear failure messages |
| Test grouping | Nested plain functions | `group()` | Standard; test runner aggregates pass/fail counts by group name |
| Fixture data | File-based JSON fixtures | Inline map literals | These are small models; inline maps are simpler and self-documenting |

**Key insight:** The entire test suite for this phase is 4–7 files of pure Dart. There is no infrastructure problem to solve.

## Runtime State Inventory

> Phase 3 is a pure code addition (new test files). No rename, refactor, or migration.

Not applicable — this phase adds new files only and does not touch runtime state, databases, or service configuration.

## Common Pitfalls

### Pitfall 1: AuditAnswerService instantiation triggers Supabase.instance access

**What goes wrong:** `AuditAnswerService()` has `final _client = Supabase.instance.client` at field-declaration level. In some Dart/Flutter versions, this field initializer runs at construction time, triggering `StateError: Supabase not initialized`.

**Why it happens:** Dart field initializers run before the constructor body. If the field is `late`, it defers until first access.

**How to avoid:** Check if instantiation throws. If it does, two options: (a) add `TestWidgetsFlutterBinding.ensureInitialized()` at top of `main()` — this initializes Flutter but not Supabase, and the field access will throw only if `_client` is actually accessed; (b) extract `calculateConformity` to a standalone function or static method (preferred for testability — but CLAUDE.md prohibits refactoring service APIs in this milestone). Use option (a) if needed.

**Warning signs:** `StateError: Supabase not initialized` in test output.

**Verified diagnosis:** [VERIFIED: reading `audit_answer_service.dart` line 10 — `final _client = Supabase.instance.client;` is a non-late field initializer. This WILL run at `AuditAnswerService()` construction. The test must either mock Supabase init or work around it.]

**Recommended mitigation:** Since `calculateConformity` takes only `List<TemplateItem>` and `Map<String, String>` — both plain Dart — and never calls `_client`, the cleanest approach without refactoring is to test `calculateConformity` by calling it as a static-style standalone function. To avoid touching the service class: either (a) inline the logic test by re-implementing as a local function in the test file with the same algorithm (not recommended — duplicates logic), or (b) accept that `AuditAnswerService()` will throw and refactor `calculateConformity` to a `static` method. Option (b) is a one-line change (`static double calculateConformity(...)`) and is consistent with the existing codebase pattern — it is the right fix and is not a state management refactor.

### Pitfall 2: Audit.fromMap requires nested join maps

**What goes wrong:** `Audit.fromMap` reads nested keys like `map['audit_types']?['name']` and `map['companies']?['requires_perimeter']`. If the test fixture map omits these nested maps, the fields default to `''` / `false` — but the test must be aware of the structure.

**Why it happens:** Audit was designed around Supabase join queries that return nested objects. The fixture must replicate this structure.

**How to avoid:** Include the nested maps in test fixtures: `{'audit_types': {'name': 'Safety', 'icon': '🔒', 'color': '#FF0000'}, 'companies': {'name': 'Acme', 'requires_perimeter': true}, 'auditor': {'full_name': 'João'}}`.

### Pitfall 3: Perimeter.buildTree mutates the input list objects

**What goes wrong:** `buildTree` calls `p.children = []` for every perimeter in the flat list, then appends children. If the same `Perimeter` objects are reused across tests, the second test may see stale children from the first test.

**Why it happens:** `Perimeter.children` is a mutable `List<Perimeter>` field (not final).

**How to avoid:** Construct fresh `Perimeter` objects in each test case. Do not share instances between test groups.

### Pitfall 4: AppRole.canEdit does not exist

**What goes wrong:** The ROADMAP success criterion #3 says "AppRole tem testes verificando `canAccessAdmin`, `canEdit`". `canEdit` is not in `app_roles.dart` and has never existed. Writing a test that calls `AppRole.canEdit(...)` will fail to compile.

**Why it happens:** The roadmap was written before the actual code was audited; the requirement contains a phantom method.

**How to avoid:** Cover only the methods that exist: `canAccessAdmin`, `canAccessDev`, `isSuperOrDev`, and `label`. Document in the plan that `canEdit` does not exist and that the success criterion is satisfied by covering the actual helpers. This is not a gap — there is no missing test. [VERIFIED: grep for `canEdit` in `primeaudit/lib/` returns no matches]

### Pitfall 5: UserProfile model does not exist

**What goes wrong:** The ROADMAP success criterion #4 lists `UserProfile` as one of 7 models to cover. That class does not exist. The profile model is `AppUser` in `primeaudit/lib/models/app_user.dart`.

**Why it happens:** Same root cause as Pitfall 4 — roadmap written without codebase audit.

**How to avoid:** Test `AppUser.fromMap()`, not `UserProfile`. Note in plan: requirement satisfied by `AppUser` which IS the profiles model. [VERIFIED: reading `app_user.dart` — class name is `AppUser`, mapped from table `profiles`]

## Code Examples

Verified patterns from actual codebase files:

### calculateConformity — all response types

```dart
// Source: verified by reading primeaudit/lib/services/audit_answer_service.dart
// All 6 responseType branches in the switch:
// 'ok_nok'    — earned += weight if ans == 'ok'
// 'yes_no'    — earned += weight if ans == 'yes'
// 'scale_1_5' — earned += (int.parse(ans) / 5) * weight
// 'percentage'— earned += (double.parse(ans) / 100) * weight
// 'text'      — earned += weight if ans.isNotEmpty
// 'selection' — earned += weight if ans.isNotEmpty
// Empty list  — returns 100.0 (totalWeight == 0 guard)
```

### AppRole methods inventory

```dart
// Source: verified by reading primeaudit/lib/core/app_roles.dart
// Methods to test:
//   canAccessAdmin(role) — true for: superuser, dev, adm; false for: auditor, anonymous
//   canAccessDev(role)   — true for: superuser, dev; false for: adm, auditor, anonymous
//   isSuperOrDev(role)   — true for: superuser, dev; false for: adm, auditor, anonymous
//   label(role)          — 5 known roles return Portuguese labels; unknown role returns role itself
```

### fromMap fixture structures

```dart
// Source: verified by reading each model file

// AuditAnswer — simple flat map
{'id': 'aa1', 'audit_id': 'a1', 'template_item_id': 'ti1',
 'response': 'ok', 'observation': null, 'answered_at': '2024-01-01T10:00:00.000Z'}

// TemplateItem — flat map with optional fields
{'id': 'ti1', 'template_id': 't1', 'question': 'Q?',
 'response_type': 'ok_nok', 'required': true, 'weight': 3,
 'order_index': 0, 'options': []}

// AuditTemplate — with nested audit_types join
{'id': 't1', 'type_id': 'at1', 'name': 'Template A',
 'active': true, 'audit_types': {'name': 'Safety', 'icon': '🔒'}}

// AppUser — with nested companies join
{'id': 'u1', 'full_name': 'Ana', 'email': 'ana@x.com',
 'role': 'adm', 'active': true, 'created_at': '2024-01-01T00:00:00.000Z',
 'companies': {'name': 'Acme'}}

// Company — flat
{'id': 'c1', 'name': 'Acme', 'active': true,
 'requires_perimeter': false, 'created_at': '2024-01-01T00:00:00.000Z'}

// Perimeter — flat
{'id': 'p1', 'company_id': 'c1', 'parent_id': null,
 'name': 'Area A', 'active': true, 'created_at': '2024-01-01T00:00:00.000Z'}

// Audit — complex with multiple nested joins
{'id': 'a1', 'title': 'Auditoria', 'audit_type_id': 'at1',
 'template_id': 't1', 'company_id': 'c1', 'auditor_id': 'u1',
 'status': 'em_andamento', 'created_at': '2024-01-01T00:00:00.000Z',
 'audit_types': {'name': 'Safety', 'icon': '📋', 'color': '#2196F3'},
 'audit_templates': {'name': 'Template A'},
 'companies': {'name': 'Acme', 'requires_perimeter': false},
 'perimeters': null, 'auditor': {'full_name': 'Ana'}}
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `AuditAnswerService()` construction will throw `StateError: Supabase not initialized` because `_client` is a non-late field | Pitfall 1 | If Dart lazily initializes the field, no mitigation needed; but if it throws, `calculateConformity` is untestable without the static method change |
| A2 | Making `calculateConformity` a `static` method is a safe minimal change consistent with CLAUDE.md constraints (it does not add state management or break existing callers) | Common Pitfalls | If callers use the instance method pattern in a way that prevents static refactoring, alternative approach needed |

## Open Questions

1. **Does `AuditAnswerService()` throw at construction in test context?**
   - What we know: `final _client = Supabase.instance.client` is a non-late field initializer that runs at construction
   - What's unclear: Whether Flutter test runner initializes enough of Supabase for this not to throw
   - Recommendation: Plan Wave 0 should verify this with a minimal test; if it throws, add a task to make `calculateConformity` static before writing the actual tests

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | `flutter test` | ✓ | >=3.38.4 (locked) | — |
| `flutter_test` | All tests | ✓ | SDK (built-in) | — |

**Missing dependencies with no fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Flutter SDK, locked 3.38.4) |
| Config file | none (uses Flutter defaults) |
| Quick run command | `flutter test test/services/audit_answer_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QUAL-01 | `calculateConformity` for all 6 response types + empty list | unit | `flutter test test/services/audit_answer_service_test.dart` | ❌ Wave 0 |
| QUAL-02 | `canAccessAdmin`, `canAccessDev`, `isSuperOrDev`, `label` for all 5 roles | unit | `flutter test test/models/app_role_test.dart` | ❌ Wave 0 |
| QUAL-03 | `fromMap()` for Audit, AuditAnswer, AuditTemplate, TemplateItem, Perimeter, Company, AppUser | unit | `flutter test test/models/` | ❌ Wave 0 |
| QUAL-04 | `Perimeter.buildTree()` for 0, 1, 2, 3-level hierarchies | unit | `flutter test test/models/perimeter_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test` (full suite — it runs in <5s with no Supabase)
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/services/audit_answer_service_test.dart` — covers QUAL-01
- [ ] `test/models/app_role_test.dart` — covers QUAL-02
- [ ] `test/models/audit_test.dart` — covers QUAL-03 (Audit)
- [ ] `test/models/audit_answer_test.dart` — covers QUAL-03 (AuditAnswer)
- [ ] `test/models/audit_template_test.dart` — covers QUAL-03 (AuditTemplate + TemplateItem)
- [ ] `test/models/perimeter_test.dart` — covers QUAL-03 (Perimeter.fromMap) + QUAL-04 (buildTree)
- [ ] `test/models/company_test.dart` — covers QUAL-03 (Company)
- [ ] `test/models/app_user_test.dart` — covers QUAL-03 (AppUser)

## Sources

### Primary (HIGH confidence)

- [VERIFIED: primeaudit/lib/services/audit_answer_service.dart] — calculateConformity implementation, all 6 responseType branches, Supabase client field
- [VERIFIED: primeaudit/lib/core/app_roles.dart] — complete AppRole methods inventory; `canEdit` confirmed absent
- [VERIFIED: primeaudit/lib/models/perimeter.dart] — buildTree algorithm, mutable children field
- [VERIFIED: primeaudit/lib/models/audit.dart] — Audit.fromMap nested join structure
- [VERIFIED: primeaudit/lib/models/audit_answer.dart] — AuditAnswer.fromMap flat map
- [VERIFIED: primeaudit/lib/models/audit_template.dart] — AuditTemplate.fromMap, TemplateItem.fromMap
- [VERIFIED: primeaudit/lib/models/app_user.dart] — AppUser (the UserProfile equivalent), fromMap with companies join
- [VERIFIED: primeaudit/lib/models/company.dart] — Company.fromMap flat map
- [VERIFIED: primeaudit/test/widget_test.dart] — smoke test already passing (counter test was already replaced in Phase 1)
- [VERIFIED: flutter test output] — `+25 ~2: All tests passed!` — suite is currently green

### Secondary (MEDIUM confidence)

- [VERIFIED: primeaudit/pubspec.yaml] — no additional test packages declared; `flutter_test` is the only test dependency

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pubspec.yaml confirmed, `flutter_test` is the only dependency needed
- Architecture: HIGH — all source files read directly; no assumptions about structure
- Pitfalls: HIGH for Pitfalls 1/4/5 (verified by source reading); MEDIUM for Pitfall 3 (Dart mutation behavior — known language property)

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable — no external services; only changes if someone modifies the target source files)
