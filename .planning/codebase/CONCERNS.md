---
generated: 2026-04-16
focus: concerns
---

# Codebase Concerns

**Analysis Date:** 2026-04-16
**Project:** PrimeAudit — Flutter + Supabase industrial audit app

---

## Security Concerns

### Supabase credentials committed to source code — LOW (by design, with caveats)
- **Files:** `primeaudit/lib/core/supabase_config.dart` (lines 6–7)
- **What:** The Supabase project URL and `anonKey` are hardcoded as Dart `const` strings. The file includes a comment acknowledging that the `anonKey` is safe client-side because Supabase RLS policies restrict what it can do.
- **Real risk:** This is standard practice for Supabase Flutter apps — the anon key is intentionally public. However, the risk is fully dependent on RLS policies being correctly implemented on the Supabase side, which cannot be verified from this codebase alone. If RLS is misconfigured or absent on any table, the anon key becomes a data exposure vector.
- **Recommendation:** Document which tables have RLS enabled. Add a note in `supabase_config.dart` linking to the Supabase project's RLS status for future maintainers.

### Role enforcement is client-side only — HIGH
- **Files:** `primeaudit/lib/core/app_roles.dart`, `primeaudit/lib/screens/home_screen.dart` (line 181), `primeaudit/lib/screens/admin/admin_screen.dart`, `primeaudit/lib/screens/settings_screen.dart` (line 98)
- **What:** Admin screens are hidden from non-admin users in the UI using `AppRole.canAccessAdmin(_role)`, but there is no server-side enforcement visible in the Dart codebase. The role is fetched from `profiles.role` and used only to filter UI visibility. Any user who discovers the route or calls the services directly can bypass these guards.
- **Specific issue:** `UserService.updateRole()` and `UserService.updateCompany()` have no client-side permission check — they call Supabase and rely entirely on RLS. If RLS is absent, any authenticated user can promote themselves to `superuser`.
- **Mitigation required:** Supabase RLS policies on `profiles` must prevent `UPDATE` of `role` and `company_id` except by admin-level users. This cannot be confirmed from the Flutter code.

### Deactivated user bypass window — MEDIUM
- **Files:** `primeaudit/lib/services/auth_service.dart` (lines 23–35)
- **What:** After `signInWithPassword` succeeds, the code fetches the `profiles` table to check `active == false` and then calls `signOut()`. There is a small race window: between the successful Supabase sign-in and the `signOut()` call, the session is technically active. The Supabase JWT is already issued. A fast enough client intercepting the token at this point would have a valid short-lived session.
- **Impact:** Low in practice for a mobile app, but worth noting for compliance in an industrial audit context.
- **Fix approach:** Enforce deactivation in a Supabase database function or RLS policy so that `active = false` users cannot read any data, making the token useless even if intercepted.

### No CNPJ validation on registration — LOW
- **Files:** `primeaudit/lib/screens/register_screen.dart` (lines 44–71), `primeaudit/lib/services/company_service.dart` (line 66)
- **What:** The registration screen searches for a company by CNPJ, but the CNPJ field has no format validator on the form. Only length is checked (`clean.length < 14`). There is no Luhn-style digit verification. An attacker could probe the `companies` table by iterating CNPJs.
- **Fix approach:** Add a CNPJ checksum validator to the `TextFormField`'s `validator`.

---

## Performance Concerns

### Sequential N+1 database calls in `reorderItems` — HIGH
- **Files:** `primeaudit/lib/services/audit_template_service.dart` (lines 209–216)
- **What:** `reorderItems` iterates a list of item IDs and fires one `UPDATE` query per item inside a `for` loop. For a template with 20 items, this is 20 sequential round-trips to Supabase.
- **Code:**
  ```dart
  for (int i = 0; i < ids.length; i++) {
    await _client
        .from('template_items')
        .update({'order_index': i})
        .eq('id', ids[i]);
  }
  ```
- **Impact:** Noticeable lag on templates with many items (10+). Each awaited call blocks the next.
- **Fix approach:** Use a Supabase Edge Function or a PostgreSQL `UPDATE ... FROM (VALUES ...)` approach batched into a single call. Alternatively, use `Future.wait()` to issue calls in parallel, which does not reduce round-trips but eliminates sequencing delay.

### Multiple redundant `_getMyProfile()` calls — MEDIUM
- **Files:** `primeaudit/lib/services/user_service.dart` (line 11), `primeaudit/lib/services/company_service.dart` (line 11)
- **What:** Both `UserService` and `CompanyService` define an identical `_getMyProfile()` method that calls `profiles.select('role, company_id')`. On screens like `UsersTab` (`primeaudit/lib/screens/admin/users_tab.dart` line 44), `getAll()` and `getMyRole()` are called concurrently via `Future.wait`, which each independently call `_getMyProfile()` — resulting in 2–3 profile fetches per screen load.
- **Fix approach:** Extract profile fetching to a shared `ProfileCacheService` that caches the result for the session lifetime, or pass the resolved profile as a parameter from `HomeScreen` downward.

### Dashboard summary cards show placeholder `'—'` values — MEDIUM
- **Files:** `primeaudit/lib/screens/home_screen.dart` (lines 288–329)
- **What:** The four dashboard summary cards (Auditorias, Concluídas, Em andamento, Empresas) always display `'—'` because the real aggregate queries have not been implemented. This means there is a currently unused opportunity to preload statistics that would otherwise require separate queries when implemented.
- **Impact:** Not a current performance issue, but when these are implemented, naive approaches will add 3–4 extra queries per dashboard load.

### `_ItemCard` creates a `TextEditingController` per list item — LOW
- **Files:** `primeaudit/lib/screens/audit_execution_screen.dart` (lines 750–765)
- **What:** Each `_ItemCard` in the audit execution list creates its own `TextEditingController` for the observation field. For a template with 50+ items, this creates 50+ controllers in memory even for items whose observation field is never expanded.
- **Fix approach:** Lazy-initialize the controller only when `_showObs` becomes `true`.

---

## Maintainability Concerns

### `audit_execution_screen.dart` is 1,395 lines — MEDIUM
- **Files:** `primeaudit/lib/screens/audit_execution_screen.dart`
- **What:** The file contains the main screen, 8 private widget classes (`_ReadOnlyBanner`, `_SectionBlock`, `_ItemCard`, `_GuidanceTile`, `_AnswerWidget`, `_TwoOptionButtons`, `_ScaleButtons`, `_PercentageSlider`, `_TextAnswer`, `_SelectionAnswer`, `_Badge`), and all answer-type rendering logic. This makes the file hard to navigate and each answer widget hard to test in isolation.
- **Fix approach:** Extract answer-type widgets into `lib/widgets/audit_answer_widgets/` — one file per response type.

### `audits_screen.dart` is 1,503 lines — MEDIUM
- **Files:** `primeaudit/lib/screens/audits_screen.dart`
- **What:** The file mixes the audit list screen, the new-audit bottom sheet (multi-step wizard), perimeter tree navigation, and the deadline picker into a single file. The `_NewAuditSheet` alone accounts for ~700 lines.
- **Fix approach:** Extract `_NewAuditSheet` and its sub-widgets to `lib/screens/audits/new_audit_sheet.dart`.

### Silent error swallowing in critical paths — HIGH
- **Files:**
  - `primeaudit/lib/screens/home_screen.dart` line 55: `} catch (_) {` — profile load failure silently shows empty name/role
  - `primeaudit/lib/screens/audit_execution_screen.dart` lines 228–229: `catch (_) { // Falha silenciosa` — answer save failure is invisible to the user
  - `primeaudit/lib/screens/audits_screen.dart` lines 448, 846, 859: bare `catch (_) {}` in data load paths
  - `primeaudit/lib/screens/register_screen.dart` line 67: `catch (_) {}` in CNPJ company search
  - `primeaudit/lib/screens/settings_screen.dart` line 65: `catch (_) {}` during settings load
- **Impact for audit answer save:** If `upsertAnswer` fails (network loss, RLS violation), the auditor sees their answer selected in the UI but it was never persisted. On finalize they get a different conformity score than what the UI showed. This is the highest-impact silent failure.
- **Fix approach:** At minimum, log errors to the console. For the answer save path, consider a local pending queue with retry, or show a subtle error indicator (red border on the item card) so the auditor knows their answer did not save.

### `_getMyProfile()` is duplicated across two services — LOW
- **Files:** `primeaudit/lib/services/user_service.dart` lines 11–16, `primeaudit/lib/services/company_service.dart` lines 11–16
- **What:** Identical implementation — same query, same column selection, same null-assert on `currentUser`. Any change must be made in two places.
- **Fix approach:** Extract to a shared `ProfileService` or inline utility, or merge into a single source.

### `_inputDecoration` method is duplicated across three screens — LOW
- **Files:** `primeaudit/lib/screens/login_screen.dart` (line 228), `primeaudit/lib/screens/register_screen.dart` (line 399), `primeaudit/lib/screens/templates/template_builder_screen.dart` (line 369)
- **What:** Each screen defines its own `_inputDecoration` / `_inputDec` helper that produces nearly identical `InputDecoration` objects. Any styling change to input fields must be applied in three places.
- **Fix approach:** Extract to `lib/core/app_input_decoration.dart` as a shared utility.

### `Perimeter.depth` property returns `1` unconditionally — LOW
- **Files:** `primeaudit/lib/models/perimeter.dart` (lines 57–60)
- **What:** The `depth` getter returns hardcoded `1` for any perimeter with a `parentId`, regardless of actual nesting depth. A comment admits "será calculado dinamicamente na UI". The property is never used in UI code, making it dead code with an incorrect implementation.
- **Fix approach:** Either implement depth correctly (requires walking the tree) or remove the property until it's needed.

---

## Scalability Concerns

### `AuditService.getAudits` loads all audits with no pagination — MEDIUM
- **Files:** `primeaudit/lib/services/audit_service.dart` (lines 32–39)
- **What:** `getAudits()` fetches every audit record for a company with a single query and no `limit`/`range`. All filtering (by status, auditor, search text) happens client-side after the full list is loaded (`primeaudit/lib/screens/audits_screen.dart` lines 122–143).
- **Impact:** For a company with thousands of audits, this will transfer a large payload and hold all records in memory. The five-column join (`audit_types`, `audit_templates`, `companies`, `perimeters`, `profiles`) amplifies payload size.
- **Fix approach:** Add server-side filtering and pagination via Supabase `.range(from, to)` and move at least status/auditor filters to the query.

### Template items loaded fully on every audit open — MEDIUM
- **Files:** `primeaudit/lib/screens/audit_execution_screen.dart` (lines 47–51), `primeaudit/lib/services/audit_template_service.dart` (lines 147–153)
- **What:** `getItems()` loads all items for a template on every audit open with no caching. If multiple auditors run the same template concurrently, each fetches the same template data independently.
- **Fix approach:** Cache template structure (sections + items) by `templateId` in memory for the session since template structure rarely changes during an active audit.

### `CompanyContextService` uses in-memory singleton with no invalidation — LOW
- **Files:** `primeaudit/lib/services/company_context_service.dart`
- **What:** The singleton caches `activeCompanyId` and `activeCompanyName` for the session. If a superuser's active company is deleted or renamed in another session, the cached context becomes stale with no invalidation mechanism.
- **Impact:** Audits could be created against a non-existent company ID, or the displayed company name diverges from the database.

### Weight system is capped at 5 with no extensibility — LOW
- **Files:** `primeaudit/lib/screens/templates/template_builder_screen.dart` (lines 289–298)
- **What:** Item weight is constrained between 1 and 5 by UI buttons with hardcoded bounds. There is no validation of this range on the service layer.
- **Impact:** Low for current usage, but businesses with complex weighting schemes (e.g., critical items with weight 10) cannot be accommodated without UI changes.

---

## Dependency Risks

### Only 3 production dependencies — LOW risk (current state)
- **File:** `primeaudit/pubspec.yaml`
- **Dependencies:** `supabase_flutter: ^2.8.4`, `shared_preferences: ^2.3.3`, `cupertino_icons: ^1.0.8`
- **Assessment:** The dependency surface is minimal, which is a strength. No abandoned or high-risk packages detected.
- **Note:** `supabase_flutter ^2.8.4` is relatively recent. The `^` constraint allows minor updates, which is appropriate.

### No offline capability dependency — MEDIUM (missing feature risk)
- **What:** There is no local database (e.g., `sqflite`, `drift`, `isar`) in the dependencies. The app is fully online-dependent. In industrial environments (factories, remote sites), network connectivity may be unreliable.
- **Impact:** If network drops mid-audit, answer saves fail silently (see silent error concern above), and the user has no visual indication. There is no queue to replay failed upserts.

---

## Technical Debt

### Settings screen stores settings locally only — HIGH (missing feature)
- **Files:** `primeaudit/lib/services/settings_service.dart`, `primeaudit/lib/screens/settings_screen.dart`
- **What:** All audit settings (minimum conformity threshold, default deadline days, require justification, allow edit after submit, maintenance mode) are persisted in `SharedPreferences` on the local device only. These settings have no effect on other users or devices. A setting like "maintenance mode" that claims to "block auditor access" does nothing to other devices — it only hides a toggle on the device of the person who toggled it.
- **Impact:** This is the most functionally misleading piece of the codebase. An admin enabling "maintenance mode" on their phone does not block any other user.
- **Fix approach:** These settings must be stored in a Supabase table (e.g., `company_settings` or `system_config`) and read server-side or on app start.

### Dashboard summary cards are permanent placeholders — MEDIUM
- **Files:** `primeaudit/lib/screens/home_screen.dart` (lines 288–329)
- **What:** The four metric cards on the dashboard always show `'—'`. No queries fetch actual counts. The "Atividade recente" section always shows "Nenhuma atividade recente". These are marked implicitly as future work (a comment on the notifications icon says `// futuro`).
- **Impact:** The home screen provides no value to users beyond navigation.

### `AuditService.closeAudit` sets status to `'cancelada'` — MEDIUM
- **Files:** `primeaudit/lib/services/audit_service.dart` (lines 69–73)
- **What:** The method is named `closeAudit` but sets `status = 'cancelada'`. The naming implies an "encerramento" (closure/archival) but the actual behavior is cancellation. This inconsistency is visible in `audits_screen.dart` where the UI label is "Encerrar" but the service call cancels. The docstring says "Encerra uma auditoria (status → cancelada)". For industrial audit compliance, cancelling and closing are semantically different operations.
- **Fix approach:** Either rename `closeAudit` to `cancelAudit`, or introduce a separate `closeAudit` that sets a distinct `encerrada` status.

### Notification settings exist in the UI but no push notification system is implemented — MEDIUM
- **Files:** `primeaudit/lib/screens/settings_screen.dart` (lines 205–248), `primeaudit/lib/services/settings_service.dart` (lines 27–34)
- **What:** Three notification toggles exist ("Auditorias atribuídas", "Próximas do prazo", "Relatórios gerados") and are persisted, but no push notification infrastructure (FCM, APNs, Supabase Realtime subscriptions) exists in the codebase. The notification icon in `HomeScreen` has an empty `onPressed: () {}` handler (line 93).
- **Impact:** Users toggling these settings have no effect. Misleading UX.

### Default widget test is broken — LOW
- **Files:** `primeaudit/test/widget_test.dart`
- **What:** The only test file contains a Flutter scaffold counter test that looks for a `+` button and counter text — none of which exist in `PrimeAuditApp`. This test will fail if run. It is a leftover from project scaffolding, not a real test.
- **Fix approach:** Replace with a meaningful smoke test or delete.

---

## Test Coverage Gaps

### Zero application tests — HIGH
- **What:** The entire application has no tests. The single file in `primeaudit/test/` (`widget_test.dart`) is a broken scaffold test unrelated to the app.
- **Risk areas with no test coverage:**
  - `AuditAnswerService.calculateConformity` — complex scoring logic with multiple response types and weight calculations. A bug here produces incorrect audit results.
  - `AuthService.signIn` — the deactivated-user check has no test verifying the sign-out path fires correctly.
  - `Perimeter.buildTree` — tree construction from flat list; edge cases (circular references, orphaned nodes) are untested.
  - `AuditTemplateService` filter logic — the `OR company_id.is.null,company_id.eq.$companyId` filter is business-critical and untested.
- **Priority:** The conformity calculation in `primeaudit/lib/services/audit_answer_service.dart` (lines 52–81) is the highest-priority item to test given its direct impact on audit results.

---

*Concerns audit: 2026-04-16*
