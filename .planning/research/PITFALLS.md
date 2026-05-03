# Domain Pitfalls — Checklist Module (v1.2)

**Domain:** Adding Checklist module to existing Flutter + Supabase industrial audit app
**Researched:** 2026-05-02
**Stack:** Flutter 3.38.4 / Dart 3.11.4 / Supabase (auth + db + storage + RLS)
**Constraint reminder:** No BLoC/Riverpod/Provider; setState only; idempotent migrations; do not break existing audit flow.

---

## Critical Pitfalls

### Pitfall 1: PDF Generation Freezes the UI Thread

**What goes wrong:** `pdf.save()` serializes the document synchronously on the main isolate. With 10+ photos embedded as `pw.MemoryImage`, the operation can block the UI for 2–5 seconds on mid-range Android devices, causing an "Application Not Responding" warning.

**Why it happens:** The `pdf` package (DavBfr/dart_pdf) does all layout and serialization in pure Dart, not offloaded to a background thread. `pw.MemoryImage` wraps raw `Uint8List` bytes — if you pass original camera bytes (3–10 MB each), the document can easily exceed 50 MB before any compression.

**Consequences:** Frozen UI during report generation; possible OOM crash on Android with heap < 256 MB if multiple full-resolution images are embedded simultaneously. The user cannot interrupt the freeze.

**Prevention:**
1. Resize each photo to a max of 800×800 px before embedding. Use the `image` package to decode, resize, and re-encode to JPEG bytes before passing to `pw.MemoryImage`. Do this in a preparatory step, not inside the PDF builder callback.
2. Wrap `pdf.save()` inside Flutter's `compute()` helper so serialization runs in a separate isolate and the UI remains responsive.
3. Fetch Supabase signed URLs and download all photo bytes **before** starting PDF layout — the `pdf` package builder callbacks are synchronous and do not support `await`.
4. Show a non-dismissible progress dialog while generation is in progress.

**Detection:** UI jank visible in Flutter DevTools "UI" thread graph; ANR dialogs on low-end Android; profiler shows single-frame spikes > 16 ms during `pdf.save()`.

**Phase:** REP-01 (PDF generation).

---

### Pitfall 2: Signed URLs Expire Before the PDF Builder Downloads the Images

**What goes wrong:** Supabase signed URLs expire (1 hour in `ImageService.getSignedUrl`). If the user views a completed checklist hours after execution and then generates a PDF, the URLs that were used to render thumbnails in the history screen are already expired. The PDF builder tries to download the image bytes from an expired URL and gets a 401 — the photo is silently absent from the PDF.

**Why it happens:** `ImageService.getSignedUrl()` issues time-limited URLs designed for display purposes. PDF generation re-uses those display URLs at a different point in time without re-requesting fresh ones.

**Consequences:** Photos missing from generated PDF with no visible error message; intermittent and hard to reproduce because it is time-dependent.

**Prevention:**
1. In the PDF service, always call `ImageService.getSignedUrl()` (or download bytes directly from Supabase Storage) immediately before PDF layout — never reuse URLs cached from earlier UI rendering.
2. Download all photo bytes eagerly into a `Map<imageId, Uint8List>` at PDF generation start time, before building the document.
3. If any download fails, surface a visible choice: "X fotos nao puderam ser baixadas. Gerar PDF sem fotos ou cancelar?" — respects the core no-silent-data-loss principle.

**Detection:** PDF generated but photo slots are blank; reproducible by waiting 60+ minutes between checklist execution and PDF export.

**Phase:** REP-01.

---

### Pitfall 3: Template Clone Leaves Orphaned `sectionId` References

**What goes wrong:** When cloning a template (TMPLCK-05), the code inserts a new `checklist_template` row, then new `template_sections`, then new `template_items`. If items are inserted using the **old** source section UUIDs instead of the freshly-generated target section UUIDs, every item with a `sectionId` references a non-existent section in the cloned template.

**Why it happens:** The clone reads items from the source template where `item.sectionId` points to source section UUIDs. New sections get new UUIDs from `gen_random_uuid()`. Without explicitly mapping old → new section IDs during the clone, the reference is wrong.

**Consequences:** If the FK allows NULL, clone succeeds but all items appear under the "Geral" pseudo-section during execution — the section structure is silently destroyed. If the FK is non-nullable, the insert fails with a 23503 FK violation.

**Prevention:**
1. Build a `Map<String, String> oldToNewSectionId = {}` during section inserts, populated as each new section row is returned.
2. When inserting items, look up `oldToNewSectionId[item.sectionId]` and use the mapped value. Items with `sectionId == null` pass through unchanged.
3. Sections must be inserted and awaited before items begin — do NOT use `Future.wait` across both steps together.
4. Write an integration test: clone a template with 2 sections + 4 items (2 per section), verify all 4 items appear under the correct 2 cloned sections.

**Detection:** Cloned template shows all items under "Geral" despite the original having named sections.

**Phase:** TMPLCK-05.

---

### Pitfall 4: Auto-Save Race Condition on Free-Text and Number Fields

**What goes wrong:** If `_saveAnswer` is called on every keystroke from `onChanged` in text/number/date fields, rapid upserts can arrive at Supabase out-of-order. Because the upsert uses `onConflict: 'checklist_execution_id,item_id'`, whichever network response arrives last wins — not necessarily the last character the user typed.

**Why it happens:** The existing `AuditExecutionScreen` pattern fires `_saveAnswer` on deliberate button taps (ok_nok, yes_no, selection) — each tap fires at most once. Free-text and number fields fire `onChanged` on every keystroke. At 40 WPM, a 10-character word produces 10 upserts in ~1.5 seconds.

**Consequences:** Saved text is stale or truncated; the `_failedSaves` retry queue grows with phantom failures (the "lost" requests are not actually failures, they are just older versions); network quota wasted.

**Prevention:**
1. For `text`, `number`, and `date` response types, debounce `onChanged` with a `Timer` set to 600–800 ms. Store the `Timer?` as a field on the item card `State` and cancel it in `dispose()`.
2. Pattern: on each keystroke, cancel the previous timer and start a new one. On `dispose()`, if a pending timer exists, cancel it AND flush (call `_saveAnswer` once synchronously before disposing — this ensures the last typed value is not lost on navigation).
3. For single-tap types (ok_nok, yes_no, scale_1_5, selection, percentage), keep the current immediate-save behavior.
4. The existing `_failedSaves` + `_scheduleRetry` mechanism handles failures correctly — wire the debouncer in front of it, do not replace it.

**Detection:** Network profiler shows a burst of upsert requests matching typing speed; `answered_at` column shows sub-second intervals for a text item.

**Phase:** EXEC-05 (auto-save), EXEC-02 (response type support).

---

### Pitfall 5: Polymorphic Item Cards Lose State After Parent `setState`

**What goes wrong:** Each `_ItemCard` is a `StatefulWidget` holding a `TextEditingController` for text items. When the parent calls `setState` (e.g., after updating `_failedSaves`), Flutter rebuilds the `ListView`. If `_ItemCard` does not carry a stable `key`, Flutter matches elements by position. If any list operation changes positions (e.g., a section header is inserted), the `TextEditingController` that owned item 3 may end up controlling item 4's text field.

**Why it happens:** Without `key: ValueKey(item.id)`, Flutter's element tree reconciler uses positional matching. This is the documented behavior in flutter/flutter#100451 and flutter/flutter#62307.

**Consequences:** User-typed text appears in the wrong item's field; items visually show each other's partially-typed answers; extremely confusing UX.

**Prevention:**
1. Pass `key: ValueKey(item.id)` to every `_ItemCard` widget instantiation. Pass `key: ValueKey(section.id)` to every `_SectionBlock`.
2. The current `AuditExecutionScreen` does NOT pass these keys — this omission has been safe so far only because sections and items do not change order during execution. The checklist module must add these keys explicitly.
3. Similarly, `_TextAnswer` and any other stateful answer widget within the card should carry `key: ValueKey('${item.id}_answer')` if they are conditionally rebuilt.

**Detection:** Type text in item 3, trigger any parent `setState` (answer item 1), observe text in item 3 disappearing or moving to item 4.

**Phase:** EXEC-02 (polymorphic response widgets implementation).

---

### Pitfall 6: RLS Blocks Auditors from Seeing Global Seed Templates

**What goes wrong:** Seed templates (TMPLCK-06) are inserted with `company_id = NULL` to mark them as global. The existing RLS `auditor_select` policy checks `company_id = get_my_company_id()`. In Postgres, `NULL = <any value>` evaluates to `NULL`, not `TRUE` — so global rows with `company_id IS NULL` are invisible to auditors at the RLS layer, even though `AuditTemplateService` already uses `.or('company_id.is.null,...')` at the query level.

**Why it happens:** RLS is evaluated before the PostgREST query filter. The service-level `.or()` clause is correct, but if the policy does not allow `company_id IS NULL` rows through, they are filtered out before the client sees them.

**Consequences:** After running the seed migration, auditors and adm users see an empty checklist template list. Superuser/dev see the templates correctly. The bug is invisible to developers testing as superuser.

**Prevention:**
1. Write the SELECT policy for the checklist templates table as:
   ```sql
   USING (
     get_my_role() IN ('auditor', 'adm')
     AND (company_id IS NULL OR company_id = get_my_company_id())
   )
   ```
2. Mirror this for all checklist-related tables that have a `company_id` column and may contain global rows.
3. Always verify new RLS policies by testing as an `auditor` role (not as superuser), both for company-specific and global rows.

**Detection:** Checklist template list is empty for auditors; superuser sees all templates.

**Phase:** TMPLCK-06 (seed migration), any migration creating new tables with global rows.

---

### Pitfall 7: Android FileProvider Missing for PDF Sharing

**What goes wrong:** `share_plus` on Android exposes files via a `FileProvider`. Without a `FileProvider` declaration in `AndroidManifest.xml`, sharing a PDF file stored in `getTemporaryDirectory()` throws `FileUriExposedException` at runtime on Android 7+ (API 24+). Additionally, because `share_plus` launches the share sheet in a separate system activity by default, the app cannot reliably detect when sharing completes — temp PDF files accumulate indefinitely in the cache directory.

**Why it happens:** No existing feature in PrimeAudit has required a `FileProvider` — the current `AndroidManifest.xml` likely does not have one. `share_plus` docs state that `XFile.fromData` writes to the app cache directory and "the OS should take care of deleting those files" — but in practice, documented issue fluttercommunity/plus_plugins#1299 shows the OS does not reliably clean up, and apps can reach multiple GBs of cached temp files.

**Consequences:** Crash with `FileUriExposedException: file:///data/...` when the share sheet opens; or, on devices where sharing works, progressive storage growth from uncleaned temp PDFs.

**Prevention:**
1. Add `FileProvider` to `AndroidManifest.xml` under `<application>`:
   ```xml
   <provider
     android:name="androidx.core.content.FileProvider"
     android:authorities="${applicationId}.fileprovider"
     android:exported="false"
     android:grantUriPermissions="true">
     <meta-data
       android:name="android.support.FILE_PROVIDER_PATHS"
       android:resource="@xml/file_provider_paths"/>
   </provider>
   ```
2. Create `android/app/src/main/res/xml/file_provider_paths.xml` with a `<cache-path name="cache" path="."/>` entry.
3. On app startup (in `main()` or `HomeScreen.initState()`), delete PDF files older than 24 hours from `getTemporaryDirectory()`.
4. Use `getTemporaryDirectory()` for PDF storage — no `WRITE_EXTERNAL_STORAGE` permission is needed on Android 10+ when writing to app-private temp storage.

**Detection:** `PlatformException: FileUriExposedException` in crash logs when user taps share; progressive growth of app storage visible in Android Settings.

**Phase:** REP-02 (export and sharing).

---

## Moderate Pitfalls

### Pitfall 8: Signature PNG Bloating the PDF

**What goes wrong:** The `signature` package's `toPngBytes()` renders the canvas at the device's native pixel ratio. On a 1440×3200 device with `pixelRatio: 3.0`, a 400×150 logical-pixel signature canvas produces a 1200×450 px PNG, approximately 500 KB–2 MB per signature. Embedded directly in the PDF, this bloats file size unnecessarily.

**Prevention:**
1. Wrap the `Signature` widget in a fixed-size `SizedBox` (e.g., `400×150` logical pixels) to constrain the canvas dimensions.
2. Call `controller.toPngBytes(pixelRatio: 2.0)` explicitly — do not use the default device pixel ratio. This caps the raster output at 800×300 px, producing a PNG of ~50–150 KB.
3. Store the signature in Supabase Storage (same bucket pattern as checklist images, separate path prefix `signatures/`), not as base64 in a database column. A base64 text column of 500 KB adds significant overhead to every RLS scan that returns that row.

**Detection:** Generated PDF with one signature and no photos exceeds 2 MB; signature column in `checklist_executions` shows base64 string > 100 KB.

**Phase:** EXEC-06 (digital signature).

---

### Pitfall 9: Seed Migration Duplicates Global Templates on Re-Run

**What goes wrong:** If the seed migration is executed multiple times (new developer onboarding, CI reset, accidental re-run), `INSERT` statements without conflict guards create duplicate global templates. Unlike schema DDL (`CREATE TABLE IF NOT EXISTS`), data inserts are not idempotent by default.

**Prevention:**
1. Assign hardcoded, deterministic UUIDs to each seed template, section, and item. `gen_random_uuid()` at INSERT time is NOT idempotent.
2. Use `INSERT INTO ... ON CONFLICT (id) DO NOTHING` for every seed row.
3. If a `name` uniqueness constraint on global templates is preferred, create:
   ```sql
   CREATE UNIQUE INDEX IF NOT EXISTS idx_checklist_templates_global_name
     ON checklist_templates (name) WHERE company_id IS NULL;
   ```
   Then use `ON CONFLICT (name) WHERE company_id IS NULL DO NOTHING`.
4. Seed for sections and items must also use hardcoded UUIDs — sections reference the template UUID, items reference both the template UUID and the section UUID.

**Detection:** Template list shows duplicate names for global templates after running the seed migration twice.

**Phase:** TMPLCK-06.

---

### Pitfall 10: Clone Inherits `active = false` and `company_id = NULL`

**What goes wrong:** When a superuser deactivates a global seed template (`active = false`) and a company user then clones it, the clone inherits `active = false` and `company_id = NULL`. The clone is immediately invisible in the template list (filtered by `active = true`), and is globally visible rather than company-scoped.

**Prevention:**
1. The clone operation must always force `active = true` on the new template row.
2. The clone operation must always set `company_id = CompanyContextService.instance.activeCompanyId` — never copy `NULL` from a global template to a user-created clone.
3. The clone service method signature should make this explicit: `cloneTemplate(sourceId, targetCompanyId)` — the caller is responsible for passing the company ID, not deriving it inside the service.

**Detection:** User clones a template and the cloned template does not appear in the list, or appears for all companies.

**Phase:** TMPLCK-05.

---

### Pitfall 11: `BuildContext` Referenced Inside the PDF Builder After Screen Disposal

**What goes wrong:** The PDF generation function may try to access `AppTheme.of(context)` (for color tokens) or `CompanyContextService` via context inside the builder lambda. If the user navigates away while PDF generation is running in a `compute()` call, the calling screen is disposed. When the `compute()` completes and the `.then()` callback runs, `context` is invalid.

**Consequences:** `FlutterError: Looking up a deactivated widget's ancestor` thrown in the `.then()` handler; PDF may have been generated successfully but the result cannot be displayed to the user.

**Prevention:**
1. Extract all context-dependent values (company name, user name, theme colors expressed as hex strings) into plain local variables before calling the PDF generation function.
2. The PDF builder function must be a pure Dart function accepting only plain data — no `BuildContext`, no `AppTheme`, no singletons. Pass everything as parameters.
3. In the `.then()` callback, always guard with `if (mounted)` before calling `setState` or showing a snackbar.

**Detection:** `FlutterError: Looking up a deactivated widget's ancestor` in logs; only reproducible by tapping "back" during PDF generation.

**Phase:** REP-01.

---

### Pitfall 12: Missing `NOTIFY pgrst, 'reload schema'` in New Migrations

**What goes wrong:** Every migration in this project ends with `NOTIFY pgrst, 'reload schema'`. If a new checklist migration omits this line, PostgREST does not reload its schema cache. API calls against new tables return `{"code":"42P01","message":"relation \"public.checklist_executions\" does not exist"}` even though the table exists in the DB.

**Prevention:**
1. `NOTIFY pgrst, 'reload schema';` must be the last line of every migration file, without exception.
2. Add this to the migration review checklist before merging.

**Detection:** PostgREST 42P01 error on calls to new tables despite successful table creation.

**Phase:** All DB migration phases.

---

### Pitfall 13: `_TextAnswer` Controller Not Updated When Draft Answers Load Asynchronously

**What goes wrong:** `_TextAnswer` initializes its `TextEditingController` with `widget.initial` in `initState`. If the parent loads draft answers asynchronously and calls `setState` after the text field widget is already built, the controller text is stale — `initState` is not called again for existing widgets.

**Why it happens:** Flutter does not re-run `initState` on prop changes. `didUpdateWidget` must be overridden to respond to changed props. The current `_TextAnswer` in `AuditExecutionScreen` does not override `didUpdateWidget` — this is safe there because answers are loaded before the widget tree is built (`_loading = true` blocks rendering until data is ready). If the checklist screen uses a different loading strategy, this assumption breaks.

**Prevention:**
1. Follow the exact same loading pattern as `AuditExecutionScreen._load()`: set `_loading = true`, load all data (including draft answers), set `_loading = false` in a single `setState`. Never render the item list until draft data is fully loaded.
2. If deferred loading is ever added later, override `didUpdateWidget` in `_TextAnswer`: update `_ctrl.text` only when `widget.initial != oldWidget.initial && _ctrl.text != widget.initial`.

**Detection:** Text fields show empty after draft answers are loaded; answers for text items appear missing but are present in the DB.

**Phase:** EXEC-05 (auto-save draft loading).

---

## Minor Pitfalls

### Pitfall 14: Drawer Entry "Checklist" Not Gated by RBAC

**What goes wrong:** NAV-01 adds a Checklist entry to the `HomeScreen` drawer. If added unconditionally, the `anonymous` role (no company context) navigates to the checklist screen and triggers company-scoped queries that return RLS errors or empty data with no clear user feedback.

**Prevention:** Follow the existing `HomeScreen` drawer pattern. Only show the Checklist entry if `role != 'anonymous'`. Auditors should see it; anonymous should not. Mirror the same `AppRole` check used for Auditorias.

**Phase:** NAV-01.

---

### Pitfall 15: `selection` Type Items Render as "Nenhuma opcao configurada" Without `options` Column

**What goes wrong:** If the new checklist templates table omits the `options TEXT[]` column (or names it differently), `TemplateItem.fromMap` returns an empty `options` list and the `_SelectionAnswer` widget shows "Nenhuma opcao configurada." — the user cannot answer the item at all.

**Prevention:** Ensure the checklist template items table includes `options TEXT[]` column with `DEFAULT '{}'`. Verify the migration before the RLS step. Copy the same `(map['options'] as List?)?.cast<String>() ?? []` deserialization pattern.

**Phase:** TMPLCK-02 (template CRUD), EXEC-02 (selection type).

---

### Pitfall 16: PDF File Not Flushed Before `Share.shareXFiles` on iOS

**What goes wrong:** If `File.writeAsBytes(pdfBytes)` is called without `flush: true` before calling `Share.shareXFiles`, on iOS the file handle may not be fully flushed to disk at the time the share sheet reads it. The shared file can be 0 bytes or truncated.

**Prevention:** Always `await file.writeAsBytes(pdfBytes, flush: true)` before sharing. The `flush: true` parameter forces kernel buffer flush before the `Future` completes.

**Phase:** REP-02.

---

## Integration Risks with Existing Audit Flow

### Risk 1: Do Not Reuse `AuditAnswerService` for Checklist Answers

The new checklist module has separate DB tables (`checklist_executions`, `checklist_answers`). Reusing `AuditAnswerService` would write to `audit_answers` with wrong FK constraints and wrong RLS scoping. Create a dedicated `ChecklistAnswerService`. The upsert conflict key will also differ: `checklist_execution_id,item_id` instead of `audit_id,template_item_id`.

### Risk 2: Capture `activeCompanyId` in `initState`, Not in Callbacks

`CompanyContextService` is a singleton mutated imperatively. If a superuser switches company context while a checklist execution screen is open in the back stack, the next auto-save will use the new company ID, writing checklist answers scoped to the wrong company. Mitigation: in the checklist execution screen's `initState`, capture `final _companyId = CompanyContextService.instance.activeCompanyId` and use that captured value everywhere — never call the singleton inside save callbacks.

### Risk 3: Photos Must Use a Separate Bucket from `audit-images`

The `audit_item_images` table has a non-nullable FK to `audits(id)`. Checklist photos do not have an audit ID — they belong to a `checklist_execution`. Reusing the `audit-images` bucket and table requires either making the FK nullable (breaking existing RLS assumptions) or adding complex union queries. Use a separate `checklist-images` bucket and `checklist_item_images` table with FK to `checklist_executions`. The path convention should be `{companyId}/{executionId}/{itemId}/{uuid}.jpg`.

### Risk 4: `HomeScreen` Drawer Index Stability

The drawer is built with a hardcoded item list. Adding "Checklist" between existing entries will shift the indices of all subsequent entries, potentially breaking any `onTap` handlers that use positional index. Use named route navigation (already the pattern in `HomeScreen`) rather than index-based routing when adding the new entry.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| TMPLCK-05 — Clone | Orphaned section IDs on items (Pitfall 3) | Build old→new section UUID map before inserting items |
| TMPLCK-05 — Clone | Clone inherits `active = false`, `company_id = null` (Pitfall 10) | Force `active = true`, `company_id = activeCompanyId` |
| TMPLCK-06 — Seed | Duplicate templates on migration re-run (Pitfall 9) | Hardcode UUIDs + `ON CONFLICT (id) DO NOTHING` |
| TMPLCK-06 — Seed | Auditors cannot see global templates (Pitfall 6) | RLS SELECT must include `company_id IS NULL` branch |
| EXEC-02 — Response types | State loss from missing keys (Pitfall 5) | `key: ValueKey(item.id)` on every item card |
| EXEC-05 — Auto-save | Race condition on text field saves (Pitfall 4) | Debounce 600–800 ms for text/number/date types |
| EXEC-05 — Draft loading | Text controller stale after async load (Pitfall 13) | Load all drafts before building widget tree |
| EXEC-06 — Signature | Signature PNG bloating PDF (Pitfall 8) | Fixed canvas size + `pixelRatio: 2.0` |
| REP-01 — PDF generation | UI thread freeze (Pitfall 1) | `compute()` + pre-resize photos to 800×800 |
| REP-01 — PDF generation | Expired signed URLs missing from PDF (Pitfall 2) | Re-fetch fresh URLs immediately before download |
| REP-01 — PDF generation | Context invalid in PDF builder callback (Pitfall 11) | Extract all context values before `compute()` call |
| REP-02 — PDF sharing | FileProvider crash on Android 7+ (Pitfall 7) | `FileProvider` in `AndroidManifest.xml` + paths XML |
| REP-02 — PDF sharing | Temp PDFs accumulate in cache (Pitfall 7) | Delete `*.pdf` files older than 24h on app startup |
| REP-02 — PDF sharing | iOS file not flushed before share sheet (Pitfall 16) | `writeAsBytes(bytes, flush: true)` before `shareXFiles` |
| All DB migrations | Missing `NOTIFY pgrst` (Pitfall 12) | Last line of every migration, non-negotiable |
| NAV-01 — Drawer | Anonymous role access (Pitfall 14) | Mirror existing RBAC guard pattern from drawer |

---

## Sources

- [flutter/flutter#100451](https://github.com/flutter/flutter/issues/100451) — ListView state assignment by position vs. key
- [flutter/flutter#62307](https://github.com/flutter/flutter/issues/62307) — ListView.builder key not preserved
- [fluttercommunity/plus_plugins#1299](https://github.com/fluttercommunity/plus_plugins/issues/1299) — share_plus temp file accumulation
- [DavBfr/dart_pdf issues #529, #807, #920](https://github.com/DavBfr/dart_pdf) — network image fetch in PDF builder
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) — NULL comparison behavior in policies
- [Supabase Database Migrations](https://supabase.com/docs/guides/deployment/database-migrations) — idempotent seed patterns
- [Android Developers — FileProvider](https://developer.android.com/training/secure-file-sharing/setup-sharing)
- [flutter/flutter#60160](https://github.com/flutter/flutter/issues/60160) — Image.memory retaining Uint8List in heap
