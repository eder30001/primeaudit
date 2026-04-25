---
phase: 07-dashboard
reviewed: 2026-04-25T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - primeaudit/lib/services/dashboard_service.dart
  - primeaudit/test/services/dashboard_service_test.dart
  - primeaudit/pubspec.yaml
  - primeaudit/lib/screens/home_screen.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-04-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the dashboard feature files: `DashboardService`, `HomeScreen`, `pubspec.yaml`, and the unit-test file for dashboard aggregation logic.

The implementation is well-structured. The role-scope rules (D-05 through D-07), KPI counting logic, chart aggregation, and the Phase 8 fallback for `corrective_actions` are all correctly implemented. The test file mirrors the screen logic faithfully with good coverage of edge cases.

Four warnings were found: an unguarded `_loadProfile` catch block that silently swallows auth errors (including navigation-critical ones), a bare `cast` on `List` data from Supabase that will throw an unhandled type error if the SDK ever returns a non-`List`, an unbounded chart height formula that can overflow on large datasets, and a missing `mounted` check before the `setState` inside `_buildChartData`'s caller path after an `await`. Three info items cover a pub constraint drift, a missing error retry button on the dashboard error state, and a TODO notification button.

---

## Warnings

### WR-01: Silent catch in `_loadProfile` hides critical errors

**File:** `primeaudit/lib/screens/home_screen.dart:71`
**Issue:** The outer `catch (_)` block in `_loadProfile` discards every exception — including network failures, auth exceptions, and unexpected runtime errors — with no user feedback and no logging. If `_userService.getById` or `CompanyContextService.instance.init` throws, the screen silently falls through to `_loading = false` and renders an empty dashboard with no way for the user to retry. This violates the project's "no silent data loss" principle and makes diagnosing production failures impossible.

**Fix:**
```dart
} catch (e) {
  if (mounted) {
    setState(() => _dashboardError =
        'Erro ao carregar perfil. Puxe a tela para baixo para tentar novamente.');
  }
  // Optionally: debugPrint('[HomeScreen] _loadProfile error: $e');
} finally {
  if (mounted) setState(() => _loading = false);
}
```

---

### WR-02: Unsafe `(data as List)` cast in `DashboardService` will throw on unexpected response

**File:** `primeaudit/lib/services/dashboard_service.dart:23` and `33`
**Issue:** Both `getOpenActionsCount` and `getCompaniesCount` cast the Supabase response directly to `List` with `(data as List).length`. For `getOpenActionsCount` the cast is inside a try/catch so it is caught; however for `getCompaniesCount` (line 33) there is no try/catch, so a `CastError` — e.g., if the Supabase SDK version change returns a typed `PostgrestList` that isn't assignment-compatible with `List` — would propagate uncaught and crash the entire `_loadDashboard` pipeline.

Additionally, in modern `supabase_flutter` 2.x the `.select()` call already returns `List<Map<String, dynamic>>` without needing a cast; the explicit `as List` is unnecessary and masks type-checker coverage.

**Fix:**
```dart
// getCompaniesCount — remove unsafe cast and add error boundary
Future<int> getCompaniesCount() async {
  final data = await _client.from('companies').select('id');
  return data.length; // data is already List<Map<String,dynamic>>
}

// getOpenActionsCount — same treatment
final data = await query;
return data.length;
```

---

### WR-03: Chart height formula can produce a negative or zero height for empty-after-filter data

**File:** `primeaudit/lib/screens/home_screen.dart:482`
**Issue:** The `SizedBox` height is computed as `data.length * 48.0 + 40`. The `_buildConformityChart` method guards against `data.isEmpty` (returns a placeholder at line 464), so an empty list never reaches this path. However, `data.length * 48.0 + 40` grows unboundedly — for 50 templates this produces a 2440px tall widget inside a `SingleChildScrollView`, which will cause a very long render and potential jank. More critically, `fl_chart`'s `BarChart` inside a `SingleChildScrollView` with an unconstrained height can trigger a Flutter layout assertion in certain device configurations.

**Fix:** Cap the chart height at a reasonable maximum and make it scrollable internally if the list is large:
```dart
final chartHeight = (data.length * 48.0 + 40).clamp(120.0, 480.0);
return SizedBox(
  height: chartHeight,
  child: BarChart(...),
);
```

---

### WR-04: `_loadDashboard` does not guard against `mounted` before `setState` in the error path after sequential `await`s

**File:** `primeaudit/lib/screens/home_screen.dart:120-127`
**Issue:** The `catch (e)` block at line 120 calls `setState` guarded by `if (mounted)` — this is correct. However, the sequence of `await` calls (lines 88, 99, 104) means there are multiple suspension points where the widget can be unmounted. The `finally` block at line 125 also calls `setState` with a `mounted` check, which is correct. The issue is at line 119: `if (mounted) setState(...)` for the success path is correct. This is a **latent warning** rather than a current bug, but the `await _dashboardService.getCompaniesCount()` at line 104 has no try/catch of its own — if it throws (see WR-02), execution jumps directly to the outer catch, which is fine; but if the SDK throws asynchronously in a way that bypasses the try block (e.g., `PlatformException`), the `finally` block still fires. The guard is present so this is low-severity but worth confirming the pattern is intentional.

**Fix:** No code change required if WR-02 is fixed. Document the intentional omission of per-call try/catch for `getCompaniesCount` and `getAudits` — they are intentionally allowed to bubble to the outer catch so the dashboard error message is shown.

---

## Info

### IN-01: `pubspec.yaml` dependency versions are looser than the resolved lock

**File:** `primeaudit/pubspec.yaml:36`
**Issue:** `supabase_flutter: ^2.8.4` allows any 2.x version up to <3.0.0. The `CLAUDE.md` documents the resolved version as `2.12.2`. If `pubspec.lock` is not committed or is regenerated, a `flutter pub get` on a clean machine could pull `2.13.x` or later, which may introduce breaking changes in the query return types that interact with WR-02. Consider pinning to `^2.12.0` to prevent silent upgrades until explicit compatibility is verified.

**Fix:**
```yaml
supabase_flutter: ^2.12.0
```

---

### IN-02: Dashboard error state has no retry button — pull-to-refresh is the only recovery path

**File:** `primeaudit/lib/screens/home_screen.dart:428-444`
**Issue:** When `_dashboardError` is set, the UI renders a text message telling the user to "puxe a tela para baixo para tentar novamente" but the error container has no `TextButton` or `IconButton` retry. On devices where overscroll physics are disabled or unintuitive (e.g., older Android with platform scroll behavior), users may not discover pull-to-refresh. A retry button improves discoverability and accessibility.

**Fix:**
```dart
child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(_dashboardError!, ...),
    const SizedBox(height: 8),
    TextButton.icon(
      onPressed: _loadDashboard,
      icon: const Icon(Icons.refresh),
      label: const Text('Tentar novamente'),
    ),
  ],
),
```

---

### IN-03: Notification button is a no-op stub with no visual indicator

**File:** `primeaudit/lib/screens/home_screen.dart:175-178`
**Issue:** The `notifications_outlined` icon button in the `AppBar` has `onPressed: () {}` with a `// futuro` comment. This creates a tappable button that does nothing, which can confuse users. Either remove it until the feature is implemented, or disable it and add a tooltip clarifying it is coming.

**Fix:**
```dart
// Option A: remove until Phase 8+ implements notifications
// Option B: disable with tooltip
IconButton(
  icon: const Icon(Icons.notifications_outlined),
  tooltip: 'Notificações (em breve)',
  onPressed: null, // visually disabled
),
```

---

_Reviewed: 2026-04-25T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
