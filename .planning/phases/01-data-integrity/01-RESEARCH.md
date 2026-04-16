# Phase 1: Data Integrity - Research

**Researched:** 2026-04-16
**Domain:** Flutter error handling, retry queues, SnackBar UI patterns, Supabase exception types
**Confidence:** HIGH (core patterns verified against official Flutter docs and Dart source; exception taxonomy verified via pub.dev and GitHub issues)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Usar apenas snackbar para notificar falha de save (sem borda/ícone no chip da resposta).
- **D-02:** Mensagem do snackbar: `"Não foi possível salvar"` — curta, sem jargão técnico.
- **D-03:** UI otimista — resposta aparece selecionada imediatamente, sem spinner. Indicador só aparece se save falhar.
- **D-04:** Snackbar de erro inclui action button **"Tentar novamente"** que dispara `_saveAnswer` novamente.
- **D-05:** Fila de retry com exponential backoff — saves com falha ficam na fila e são reprocessados automaticamente quando conexão for restaurada.
- **D-06:** Finalização bloqueada se `_failedSaves` não estiver vazia — exibir dialog informando quantas respostas falharam.
- **D-07:** Escopo restrito ao `_saveAnswer` em `audit_execution_screen.dart` — não tocar outros catch blocks nesta fase.

### Claude's Discretion
- Estrutura interna da fila de retry (Map, Queue, ou lista de pending items)
- Estratégia de backoff (delays: 1s, 2s, 4s, ou outro)
- Se manter fila em memória ou persistir entre navegações de tela
- Como identificar o item na fila para o snackbar action button (por itemId)

### Deferred Ideas (OUT OF SCOPE)
- Modo offline completo com sync
- Indicador de conectividade de rede na tela
- Persistência da fila de retry entre fechamentos do app
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DINT-01 | Auditor vê mensagem de erro quando save de resposta falha por rede ou timeout | SnackBar with action button pattern; exception catch in `_saveAnswer` |
| DINT-02 | App exibe indicador visual de resposta "pendente" enquanto aguarda confirmação do servidor | Per-item state Map (`_pendingSaves`); optimistic UI already in place; DINT-02 aligns with D-03 (no spinner) — the "pending" concept maps to the _failedSaves state after failure, not a visual pre-confirm spinner per D-03 |
| DINT-03 | Auditor pode tentar re-salvar manualmente respostas que falharam | SnackBarAction "Tentar novamente" callback + retry queue |
</phase_requirements>

---

## Summary

Phase 1 is a targeted robustness fix for a single silent catch block in `audit_execution_screen.dart:228`. The implementation scope is narrow — no new screens, no new services, no new packages required — but the interaction between the retry queue, SnackBar lifecycle, and finalization guard has enough subtlety to warrant careful planning.

The core challenge is passing closure data (itemId + response + observation) to a SnackBar action callback that may fire after setState cycles, and managing a background retry queue in a `StatefulWidget` without a state management library. Both problems are solvable with idiomatic Flutter patterns using only what is already in the project.

The key architectural decision for Claude's discretion is to use a `Map<String, _PendingSave>` as the retry queue (matching the existing `_answers`/`_observations` Map pattern), keep it in memory only (deferred per CONTEXT.md), and drive auto-retry with `Future.delayed` and exponential backoff inside an isolate-free async loop running on the event queue.

**Primary recommendation:** Implement `_failedSaves` as a `Map<String, _PendingSave>` on the state class. A `_PendingSave` record holds `(String itemId, String response, String? observation, int attemptCount)`. The retry loop calls `_saveAnswer` for each entry, waits for success or increments attempts, and uses `Future.delayed(Duration(seconds: pow(2, attempt).toInt()))` for backoff (1s, 2s, 4s, 8s, then stop auto-retry at 4 attempts — manual retry always available via SnackBar action).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Save failure detection | Screen (StatefulWidget) | Service (throws exception) | `_saveAnswer` catches the exception; service does not handle it |
| Error notification (SnackBar) | Screen (`ScaffoldMessenger`) | — | UI feedback belongs in the screen layer per project convention |
| Retry queue state | Screen (`_AuditExecutionScreenState`) | — | No state management library; local Map on state is the established pattern |
| Background retry scheduling | Screen (async loop via `Future.delayed`) | — | In-memory only; no external scheduler needed |
| Finalization guard | Screen (`_finalize()` guard clause) | — | `_failedSaves.isNotEmpty` check before showing confirm dialog |
| Supabase upsert | Service (`AuditAnswerService.upsertAnswer`) | — | No change needed to service layer |

---

## Standard Stack

### Core (no new dependencies needed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter` SDK | ≥3.38.4 (locked) | `SnackBar`, `SnackBarAction`, `ScaffoldMessenger`, `showDialog`, `setState` | All needed APIs are in the Flutter SDK |
| `supabase_flutter` | 2.12.2 (resolved) | `PostgrestException`, `upsertAnswer` | Already the project's backend SDK |
| `dart:math` | stdlib | `pow()` for exponential backoff calculation | No package needed |

### No New Packages Required
`connectivity_plus` is **NOT** in `pubspec.yaml` and is **NOT** needed for this phase. [VERIFIED: read pubspec.yaml]

The retry queue flushes on the next `_saveAnswer` call (either manual via snackbar action, or auto via the background timer). Network restoration is detected implicitly: if the retry attempt succeeds, the item is removed from `_failedSaves`. No connectivity plugin is needed for this scope.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Map<String, _PendingSave>` | `Queue<_PendingSave>` from `dart:collection` | Map allows O(1) lookup by itemId for deduplication and snackbar action targeting; Queue would allow duplicates if user taps the same item twice |
| `Future.delayed` loop | `Timer.periodic` | `Future.delayed` is simpler for one-shot retry; `Timer.periodic` is better for a true queue flush cycle — either works, `Future.delayed` chain is more idiomatic for bounded retry attempts |
| In-memory queue | `shared_preferences` persistence | Persistence adds complexity and was explicitly deferred in CONTEXT.md |

---

## Architecture Patterns

### System Architecture Diagram

```
User taps answer
      |
      v
_onAnswer(itemId, response)
      |
      +---> setState(_answers[itemId] = response)  [optimistic UI — immediate]
      |
      +---> _saveAnswer(itemId, response)
                  |
            try { await upsertAnswer(...) }
                  |
           +------+------+
           |             |
         SUCCESS       FAILURE (any exception)
           |             |
    remove from      add to _failedSaves[itemId]
    _failedSaves     setState() to update _failedSaves count
                     |
                     +---> showErrorSnackBar(itemId, response, obs)
                     |       [SnackBar with "Tentar novamente" action]
                     |
                     +---> _scheduleRetry(itemId)
                               |
                         Future.delayed(backoff)
                               |
                         _saveAnswer(itemId, ...) [auto-retry]


_finalize() called
      |
      v
if (_failedSaves.isNotEmpty) --> showBlockDialog (count of failures)
      |
      v
else --> existing finalize confirm dialog
```

### Recommended Implementation Structure

No new files needed. All changes live in `audit_execution_screen.dart`.

New state fields to add to `_AuditExecutionScreenState`:

```dart
// Fila de retry: itemId → dados do save com falha
final Map<String, _PendingSave> _failedSaves = {};

// Controle de retry em andamento por item (evita loops duplos)
final Set<String> _retrying = {};
```

New private class (added at bottom of file, before `_Badge`):

```dart
// ---------------------------------------------------------------------------
// Dados de save pendente para retry
// ---------------------------------------------------------------------------
class _PendingSave {
  final String itemId;
  final String response;
  final String? observation;
  final int attemptCount;

  const _PendingSave({
    required this.itemId,
    required this.response,
    this.observation,
    this.attemptCount = 0,
  });

  _PendingSave copyWithAttempt() => _PendingSave(
    itemId: itemId,
    response: response,
    observation: observation,
    attemptCount: attemptCount + 1,
  );
}
```

### Pattern 1: SnackBar with Action Button Capturing Closure Data

**What:** Pass `itemId`, `response`, and `observation` into the SnackBar action callback via closure capture. Retrieve `ScaffoldMessenger` before the async gap (before any `await`), or use the state class reference.

**When to use:** Every time `_saveAnswer` throws an exception.

**Example:**
```dart
// Source: https://docs.flutter.dev/cookbook/design/snackbars
// Source: CONTEXT.md canonical ref (_snack() pattern already in screen)

void _showSaveError(String itemId, String response, String? observation) {
  if (!mounted) return;
  // Capture messenger before potential unmount
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // dismiss previous error for same item
  messenger.showSnackBar(
    SnackBar(
      content: const Text("Não foi possível salvar"),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: "Tentar novamente",
        textColor: Colors.white,
        onPressed: () {
          // Closure captures itemId, response, observation — safe, they are
          // immutable Strings copied at call time, not widget references
          _saveAnswer(itemId, response, observation: observation);
        },
      ),
    ),
  );
}
```

**Key insight on closure safety:** `itemId`, `response`, and `observation` are `String` values (immutable, not widget references). Capturing them in a closure is safe — they cannot become stale. Do NOT capture `context` directly in the action closure; capture `ScaffoldMessenger` before showing the snackbar instead.

**SnackBar behavior note:** [VERIFIED: Flutter docs] When a SnackBar has an action, it no longer auto-dismisses by default in recent Flutter versions. Call `messenger.clearSnackBars()` before showing a new error for a cleaner experience when the same item fails multiple times.

### Pattern 2: Exponential Backoff Retry Without External Package

**What:** An async loop using `Future.delayed` that retries `_saveAnswer` up to N times with doubling delays. Uses `dart:math`'s `pow()` for the delay calculation.

**When to use:** Automatically after each save failure, running in the background.

**Example:**
```dart
// Source: google/dart-neats retry library (reference implementation, not used as dep)
// Pattern: Future.delayed chain, bounded attempts

static const _maxAutoRetryAttempts = 4;
// Delays: attempt 0 = 1s, 1 = 2s, 2 = 4s, 3 = 8s

Future<void> _scheduleRetry(String itemId) async {
  if (_retrying.contains(itemId)) return; // already retrying this item
  _retrying.add(itemId);

  try {
    while (_failedSaves.containsKey(itemId)) {
      final pending = _failedSaves[itemId]!;
      if (pending.attemptCount >= _maxAutoRetryAttempts) break; // stop auto

      final delaySeconds = pow(2, pending.attemptCount).toInt(); // 1, 2, 4, 8
      await Future.delayed(Duration(seconds: delaySeconds));

      if (!mounted || !_failedSaves.containsKey(itemId)) break;

      try {
        await _answerService.upsertAnswer(
          auditId: widget.audit.id,
          templateItemId: itemId,
          response: pending.response,
          observation: pending.observation,
        );
        // Success — remove from failed
        if (mounted) setState(() => _failedSaves.remove(itemId));
        break;
      } catch (_) {
        // Still failing — increment attempt count
        if (mounted) {
          setState(() {
            _failedSaves[itemId] = pending.copyWithAttempt();
          });
        }
      }
    }
  } finally {
    _retrying.remove(itemId);
  }
}
```

**Delay schedule:** 1s → 2s → 4s → 8s → stop auto-retry (manual retry via snackbar always available).

### Pattern 3: Finalization Guard for _failedSaves

**What:** A guard clause at the start of `_finalize()` that short-circuits into a blocking dialog if `_failedSaves` is non-empty.

**When to use:** Called before the existing confirmation dialog in `_finalize()`.

**Example:**
```dart
Future<void> _finalize() async {
  // Guard: block if failed saves exist
  if (_failedSaves.isNotEmpty) {
    final count = _failedSaves.length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Respostas não salvas"),
        content: Text(
          "$count resposta${count > 1 ? 's' : ''} não ${count > 1 ? 'foram salvas' : 'foi salva'}. "
          "Resolva as falhas antes de finalizar.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
    return; // do NOT proceed to finalize
  }

  // Existing finalize dialog continues unchanged...
  final confirm = await showDialog<bool>(...);
  // ...
}
```

### Pattern 4: Revised _saveAnswer (complete replacement)

**What:** Replace the silent catch with: (1) add to `_failedSaves`, (2) show error snackbar, (3) schedule background retry.

```dart
Future<void> _saveAnswer(String itemId, String response,
    {String? observation}) async {
  // Resolve observation: passed-in wins, else map, else null
  final obs = observation ?? _observations[itemId];
  try {
    await _answerService.upsertAnswer(
      auditId: widget.audit.id,
      templateItemId: itemId,
      response: response,
      observation: obs,
    );
    // On success: clear from failed saves if it was there
    if (_failedSaves.containsKey(itemId) && mounted) {
      setState(() => _failedSaves.remove(itemId));
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _failedSaves[itemId] = _PendingSave(
        itemId: itemId,
        response: response,
        observation: obs,
      );
    });
    _showSaveError(itemId, response, obs);
    _scheduleRetry(itemId);
  }
}
```

### Anti-Patterns to Avoid

- **Capturing `context` inside SnackBar action closure:** `context` may become invalid if the widget rebuilds. Capture `ScaffoldMessenger.of(context)` before `showSnackBar` instead.
- **Using `Timer.periodic` for retry:** A periodic timer fires on a fixed interval regardless of whether the previous attempt finished. Use `Future.delayed` chain instead so retries are sequential and bounded.
- **Retrying indefinitely:** Unbounded auto-retry will keep the `_retrying` set populated and prevent GC. Cap auto-retry at 4 attempts; manual retry via snackbar is always available.
- **Showing a new snackbar for every auto-retry attempt:** Only show the snackbar on the first failure. Auto-retry is silent. The snackbar is shown once; if the user dismisses it and auto-retry also fails, the `_failedSaves` count will block finalization (D-06) — that is the user's signal.
- **Adding `_failedSaves` check to `_canFinalize` getter:** `_canFinalize` currently guards required items. Keep it as-is. The `_failedSaves` guard belongs in `_finalize()` as a separate pre-check dialog (D-06), not wired to the bottom bar button disable state (which would confuse the user — the button looks disabled for the wrong reason).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Delay calculation | Custom delay math | `dart:math pow(2, n)` | Already in stdlib, 1 line |
| Retry loop | Custom queue processor | `Future.delayed` + `while` loop | No package needed, pattern is idiomatic Dart |
| SnackBar display | Custom overlay/toast widget | `ScaffoldMessenger.showSnackBar` | Material Design standard, already used elsewhere in this screen |
| Exception catch-all | Custom exception hierarchy | `catch (e)` — catch everything | `upsertAnswer` can throw `PostgrestException` (server errors) or `ClientException`/`SocketException` (network errors); a broad catch is correct here since ALL failures should trigger the retry UI |

---

## Supabase Exception Taxonomy

This is critical for writing the correct `catch` clause in `_saveAnswer`.

| Exception Type | When Thrown | Catch Strategy |
|----------------|-------------|----------------|
| `PostgrestException` | Server-side errors: RLS violation, constraint violation, bad column name, server 4xx/5xx | Caught by `catch (e)` |
| `ClientException` (from `package:http`) | Network-level failure: connection refused, broken pipe, header not received | Caught by `catch (e)` |
| `SocketException` (from `dart:io`) | DNS failure, no network interface | Caught by `catch (e)` |
| `TimeoutException` | Long delay with no response (can be ~3 minutes on first disconnect) | Caught by `catch (e)` |

[VERIFIED: pub.dev PostgrestException class docs — has `message`, `code`, `details`, `hint` fields]
[VERIFIED: GitHub supabase/supabase-flutter#1082 and #147 — SocketException, ClientException surface from network layer]
[VERIFIED: GitHub supabase/supabase-flutter#676 — first disconnect can delay up to ~3 min before ClientException]

**Critical finding:** The first network timeout after going offline can take up to ~3 minutes. This means `_saveAnswer` may hang for a long time before throwing. The retry queue should not wait for the timeout — instead, the failed save is queued only after the exception is actually thrown. The auto-retry backoff of 1s, 2s, 4s, 8s is appropriate because by the time the first exception fires, connectivity may be restored.

**Recommendation:** Use `catch (e)` (not `on PostgrestException catch`) in `_saveAnswer` to handle all failure types uniformly. Log `e.toString()` via `debugPrint` for developer visibility without exposing to UI.

[CITED: https://github.com/supabase/postgrest-dart/blob/master/README.md — "Exceptions will not be returned within the response, but will be thrown"]
[CITED: https://pub.dev/documentation/postgrest/latest/postgrest/PostgrestException-class.html]
[ASSUMED: timeout behavior of ~3 minutes on first disconnect is from community reports, not official docs; actual timeout may vary by platform and network]

---

## Common Pitfalls

### Pitfall 1: SnackBar Accumulation on Rapid Tapping
**What goes wrong:** User rapidly taps multiple items; each failure shows a new snackbar queued behind the previous one. Ten failures = ten stacked snackbars.
**Why it happens:** `ScaffoldMessenger` queues snackbars by default.
**How to avoid:** Call `messenger.clearSnackBars()` before `showSnackBar()` to show only the most recent failure. The `_failedSaves` map tracks all failures; individual snackbars are just notifications, not the authoritative state.
**Warning signs:** Multiple snackbars piling up in rapid sequence.

### Pitfall 2: Double Retry Loop for the Same Item
**What goes wrong:** User taps "Tentar novamente" while auto-retry is already in progress for that item. Two coroutines now compete to save the same item.
**Why it happens:** `_saveAnswer` launches `_scheduleRetry` and the snackbar action also calls `_saveAnswer`.
**How to avoid:** Use `_retrying` Set as a guard in `_scheduleRetry`. The manual snackbar action calls `_saveAnswer` directly (not `_scheduleRetry`), so it bypasses the auto-retry loop and attempts immediately — this is correct. The auto-retry loop will then see the item removed from `_failedSaves` on success and exit naturally.
**Warning signs:** `_retrying` set grows without shrinking.

### Pitfall 3: Calling setState After Unmount in Retry Loop
**What goes wrong:** Widget is popped from navigation (user leaves audit screen) while retry loop is awaiting `Future.delayed`. When the delay completes, `setState` is called on a disposed widget → crash.
**Why it happens:** `await Future.delayed` suspends the coroutine; widget can be disposed during suspension.
**How to avoid:** Check `if (!mounted) break;` after every `await` in the retry loop. This is already the project's established pattern (see CONVENTIONS.md "mounted guard").
**Warning signs:** "setState called after dispose" FlutterError in logs.

### Pitfall 4: DINT-02 Requirement Interpretation Conflict
**What goes wrong:** DINT-02 says "pending indicator while awaiting server confirmation." D-03 says "no spinner." These seem contradictory.
**Why it happens:** DINT-02 was written before the discussion resolved D-03.
**How to avoid:** Treat D-03 as the authoritative resolution of DINT-02. The "pending" state is implicit — no visual indicator is shown while saving is in-flight. The indicator only appears after failure (D-01 snackbar). DINT-02 is satisfied by the combination of: (a) optimistic immediate UI update, and (b) failure indicator if save does not complete. No spinner needed.
**Warning signs:** Planner adding a spinner or border indicator to the item card.

### Pitfall 5: Forgetting to Clear _failedSaves on Successful Manual Retry
**What goes wrong:** User taps "Tentar novamente," save succeeds, but `_failedSaves` still has the item. The finalization guard incorrectly blocks.
**Why it happens:** `_saveAnswer` only clears from `_failedSaves` on the success path, and the clear must use `setState`.
**How to avoid:** The revised `_saveAnswer` above clears `_failedSaves[itemId]` on the success path using `setState`. Verify this in implementation.

---

## Code Examples

### Verified: SnackBar with action (Flutter official)
```dart
// Source: https://docs.flutter.dev/cookbook/design/snackbars
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text("Yay! A SnackBar!"),
    action: SnackBarAction(
      label: "Undo",
      onPressed: () {
        // callback fires when user taps action
      },
    ),
  ),
);
```

### Verified: Exponential backoff delay calculation
```dart
// Source: google/dart-neats retry library reference implementation
// https://github.com/google/dart-neats/blob/master/retry/lib/retry.dart
import 'dart:math';

final delaySeconds = pow(2, attemptCount).toInt(); // 1, 2, 4, 8, 16...
await Future.delayed(Duration(seconds: delaySeconds));
```

### Verified: mounted guard after await (established project pattern)
```dart
// Source: CONVENTIONS.md — "mounted guard before every setState after an await"
await someAsyncOperation();
if (!mounted) return;
setState(() { ... });
```

### Verified: showDialog return value pattern (existing in _finalize)
```dart
// Source: audit_execution_screen.dart:235 — existing _finalize implementation
final confirm = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog( ... ),
);
if (confirm != true) return;
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `catch (_) {}` silent fail | `catch (e) + setState + snackbar + retry queue` | This phase | Errors become visible and recoverable |
| No retry | Exponential backoff auto-retry + manual snackbar action | This phase | Transient network hiccups self-heal |

**Note on `SnackBar.persist`:** Flutter added a `persist` property to SnackBar (recent stable). When `persist: true`, the snackbar stays on screen until dismissed. This is NOT recommended for save errors — a 6-second duration (default with action) is sufficient and less intrusive. `persist` is mentioned for completeness only.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | First disconnect timeout is ~3 minutes before ClientException fires | Supabase Exception Taxonomy | If timeout is shorter (e.g., 30s), UX is better than expected — no risk. If longer, save hangs longer before retry queue is populated — acceptable, retry queue handles it when exception finally fires. |
| A2 | `_scheduleRetry` running in background while widget is alive will not be GC'd because state class holds strong ref | Architecture Patterns | Standard Dart async behavior — a `Future` in flight keeps its closure alive. Low risk. |
| A3 | `clearSnackBars()` is the correct API to dismiss pending snackbars | Common Pitfalls | [ASSUMED — not verified against current Flutter API docs; may need to verify `hideCurrentSnackBar` vs `clearSnackBars`] |

---

## Open Questions

1. **Does `clearSnackBars()` affect all queued snackbars or only the current one?**
   - What we know: `ScaffoldMessenger` has both `hideCurrentSnackBar()` (removes current) and `clearSnackBars()` (removes all queued)
   - What's unclear: For this use case (replace old error with new error), `clearSnackBars()` is the right choice but should be verified in implementation
   - Recommendation: Use `clearSnackBars()` before each new save error. This is intentional — only the most recent failure needs a snackbar; `_failedSaves` map tracks all.

2. **Should `_failedSaves` count be shown in the bottom bar button label?**
   - What we know: D-06 says block finalization via dialog; D-01 says snackbar-only for notification
   - What's unclear: Whether a persistent count badge on the Finalizar button would be valuable
   - Recommendation: Do not add count to button label — out of scope of D-01/D-06. The blocking dialog (D-06) gives the count when user taps Finalizar.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All UI patterns | ✓ | 3.41.6 | — |
| Dart SDK | `dart:math pow()` | ✓ | 3.11.4 | — |
| `supabase_flutter` | `upsertAnswer`, exception types | ✓ | 2.12.2 | — |
| `connectivity_plus` | Retry queue flush on reconnect | ✗ (not in pubspec) | — | Not needed — retry triggers on next `_saveAnswer` call or timer; implicit detection is sufficient |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK built-in) |
| Config file | none — `flutter test` discovers `test/` directory automatically |
| Quick run command | `cd primeaudit && flutter test test/` |
| Full suite command | `cd primeaudit && flutter test test/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DINT-01 | `_saveAnswer` catch block triggers snackbar on exception | Widget test | `flutter test test/audit_execution_save_error_test.dart` | ❌ Wave 0 |
| DINT-02 | Optimistic UI: `_answers` updated before save completes | Widget test | same file | ❌ Wave 0 |
| DINT-03 | Manual retry via snackbar action calls `_saveAnswer` again | Widget test | same file | ❌ Wave 0 |
| D-06 | `_finalize()` shows block dialog when `_failedSaves` non-empty | Widget test | same file | ❌ Wave 0 |
| Backoff | Auto-retry increments `attemptCount` on repeated failure | Unit test | `flutter test test/pending_save_test.dart` | ❌ Wave 0 |

**Note on widget tests for this phase:** Widget-testing `ScaffoldMessenger` snackbar display requires a `MaterialApp` wrapper and `tester.pump()`/`pumpAndSettle()`. Mocking `AuditAnswerService.upsertAnswer` to throw is the key setup step.

### Sampling Rate
- **Per task commit:** `cd primeaudit && flutter test test/`
- **Per wave merge:** `cd primeaudit && flutter test test/`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `primeaudit/test/audit_execution_save_error_test.dart` — covers DINT-01, DINT-02, DINT-03, D-06
- [ ] `primeaudit/test/pending_save_test.dart` — covers `_PendingSave` unit behavior and backoff logic
- [ ] No framework install needed — `flutter_test` is already a dev dependency

---

## Security Domain

Security enforcement not applicable to this phase. This phase adds no new data access paths, no new authentication flows, and no new network endpoints. The only change is how exceptions from an existing `upsertAnswer` call are handled in the UI layer. No ASVS categories are newly implicated.

---

## Sources

### Primary (HIGH confidence)
- Flutter official docs: https://docs.flutter.dev/cookbook/design/snackbars — SnackBar + SnackBarAction pattern verified
- pub.dev PostgrestException: https://pub.dev/documentation/postgrest/latest/postgrest/PostgrestException-class.html — field structure verified
- audit_execution_screen.dart (read directly) — existing patterns, `_snack` absence noted, ScaffoldMessenger usage at lines 167-173, 210-215, 290-296 verified
- audit_answer_service.dart (read directly) — `upsertAnswer` signature and exception propagation verified
- CONVENTIONS.md (read directly) — mounted guard, Map state pattern, `_answers`/`_observations` structure verified
- pubspec.yaml (read directly) — `connectivity_plus` absence confirmed

### Secondary (MEDIUM confidence)
- google/dart-neats retry source: https://github.com/google/dart-neats/blob/master/retry/lib/retry.dart — exponential backoff formula reference
- GitHub supabase/supabase-flutter#1082 — ClientException types from network layer documented
- GitHub supabase/supabase-flutter#676 — ~3 minute timeout on first disconnect (community report)

### Tertiary (LOW confidence)
- WebSearch: Flutter SnackBar `clearSnackBars()` vs `hideCurrentSnackBar()` — not cross-verified against API docs; verify in implementation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all patterns from existing code and Flutter stdlib
- Architecture: HIGH — Map-based queue matches established pattern in codebase; exception handling matches CONVENTIONS.md
- Pitfalls: HIGH — identified from codebase read (mounted guard, silent catch pattern) and Flutter SnackBar lifecycle docs
- Exception taxonomy: MEDIUM — PostgrestException verified via pub.dev; network exception types verified via GitHub issues; timeout duration is ASSUMED from community reports

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable Flutter/Supabase APIs; retry pattern is not version-sensitive)
