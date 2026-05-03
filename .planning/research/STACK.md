# Technology Stack

**Project:** PrimeAudit v1.2 Checklist
**Researched:** 2026-05-02
**Scope:** New packages required for Checklist module only. Existing validated stack (Flutter 3.38.4, Dart 3.11.4, supabase_flutter 2.12.2, image_picker, fl_chart, shared_preferences) is not re-researched here.

---

## New Dependencies for v1.2

### PDF Generation

| Package | Version | Purpose | Why |
|---------|---------|---------|-----|
| `pdf` | `^3.11.3` | Programmatic PDF document creation | Pure Dart, no native plugins, full widget-tree API (`pw.*`), MIT license, actively maintained |
| `printing` | `^5.14.2` | Native print + share sheet for PDF bytes | Companion to `pdf`; exposes `Printing.sharePdf()` which triggers the platform share sheet (covers email AND WhatsApp in one call) |

**Rationale for `pdf` over alternatives:**

- `pdf` + `printing` is the ecosystem-standard pair: every Flutter PDF tutorial and the official pub.dev recommendation leads here. Both packages share the same author (DavBfr) and version cadence.
- `syncfusion_flutter_pdf` requires a commercial license for production apps above $1M revenue and a team of 5+; adds licensing risk for no technical gain over `pdf`.
- `pdf` uses a Flutter-like widget tree (`pw.Column`, `pw.Row`, `pw.Image`) — zero new mental model for a Flutter team.
- Embeds `Uint8List` images directly via `pw.MemoryImage(bytes)` — trivially composable with Supabase Storage downloads and signature exports.

**How `printing` covers both email and WhatsApp:**

`Printing.sharePdf(bytes: pdfBytes, filename: 'checklist.pdf')` calls `UIActivityViewController` on iOS and `Intent.ACTION_SEND` on Android. The user's share sheet appears with all installed apps including Mail, Gmail, WhatsApp, Telegram, Drive, etc. No separate WhatsApp-specific package is needed. The `PdfPreview` widget also exposes `allowSharing: true` for an in-app preview + share flow if desired.

---

### Digital Signature Capture

| Package | Version | Purpose | Why |
|---------|---------|---------|-----|
| `signature` | `^9.0.0` | Canvas-based signature widget, exports as PNG bytes | Simpler API than `hand_signature`, actively fixes breaking changes in `Picture.toImage`, MIT license |

**Rationale for `signature` over alternatives:**

- `signature` exposes a `SignatureController` with `toPngBytes()` — returns `Uint8List` directly, which feeds straight into `pw.MemoryImage()` for PDF embedding. This is the critical integration path and it is one line of code.
- `hand_signature` 3.1.0+2 is more powerful (velocity-based stroke thickness, SVG export, Bezier curves) but adds complexity that a functional signature capture does not need. SVG export is irrelevant — the PDF workflow requires PNG bytes.
- `syncfusion_flutter_signaturepad` is a commercial SDK (Syncfusion Essential Studio license). Avoid for any app that may generate revenue; community license caps apply.
- `flutter_signature_pad` is abandoned (last publish 2020).

**Export integration:**

```dart
// In signature step screen
final controller = SignatureController(penStrokeWidth: 2, penColor: Colors.black);

// On confirm:
final Uint8List? signatureBytes = await controller.toPngBytes();
// Then in PDF service:
final signatureImage = pw.MemoryImage(signatureBytes!);
```

---

### File Sharing

`printing` already covers the primary share flow via `Printing.sharePdf()`. A standalone `share_plus` is only needed if you require sharing non-PDF content (text URLs, plain text) or if you want programmatic share without generating a PDF preview screen.

**Decision: Do NOT add `share_plus` as a separate dependency for v1.2.**

Reason: `printing`'s `Printing.sharePdf()` triggers the exact same platform share sheet. Adding `share_plus` (12.0.1) as well would be redundant code paths — two packages doing the same native intent call. If a future milestone requires sharing arbitrary content types, add `share_plus` then.

---

## Packages Already Present (No Action Needed)

| Package | Already In | Why Relevant to v1.2 |
|---------|-----------|----------------------|
| `image_picker` | `pubspec.yaml` | Photo-per-item capture in checklist execution |
| `supabase_flutter` | `pubspec.yaml` | Draft auto-save, checklist storage, image upload |
| `path_provider` | transitive via supabase | `getTemporaryDirectory()` for staging PDF before share |
| `shared_preferences` | `pubspec.yaml` | Persist draft checklist state across app restarts |
| `fl_chart` | `pubspec.yaml` | Conformidade charts in checklist history |

`path_provider` is already available as a transitive dependency of `supabase_flutter`. You can use `getTemporaryDirectory()` to write the PDF bytes to disk before calling `Printing.sharePdf()` — no new package needed.

---

## New Response Item Types — No New Packages

The v1.2 requirement calls for: date picker, numeric input, multiple choice.

| Item Type | Implementation | Why No Package |
|-----------|---------------|----------------|
| Date picker | `showDatePicker()` — Flutter SDK built-in | Material 3 date picker is in `flutter/material.dart`; already themed by the app |
| Numeric input | `TextFormField(keyboardType: TextInputType.numberWithOptions(decimal: true))` | Native keyboard type constraint; no validator lib needed |
| Multiple choice | Custom `StatefulWidget` with `setState` + `Checkbox` or `ChoiceChip` | Follows existing project pattern — no form-builder lib |

Adding `flutter_form_builder` or `syncfusion_flutter_datepicker` for these would violate the project constraint against introducing heavy new dependencies and is unnecessary when Flutter's own widgets cover the need.

---

## pubspec.yaml Changes

```yaml
dependencies:
  # --- NEW for v1.2 ---
  pdf: ^3.11.3
  printing: ^5.14.2
  signature: ^9.0.0
  # --- EXISTING (no change) ---
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.8.4
  shared_preferences: ^2.3.3
  fl_chart: ^1.2.0
  image_picker: ^1.1.2
```

---

## What NOT to Add

| Package | Reason |
|---------|--------|
| `share_plus` | Redundant — `Printing.sharePdf()` calls the same platform share sheet |
| `syncfusion_flutter_pdf` | Commercial license risk; `pdf` package covers all requirements |
| `syncfusion_flutter_signaturepad` | Commercial license; `signature` covers the use case |
| `hand_signature` | Overkill for functional signature capture; SVG export is not needed |
| `flutter_form_builder` | Violates project constraint; adds state complexity; built-ins suffice |
| `syncfusion_flutter_datepicker` | Commercial license; `showDatePicker()` is built-in |
| `permission_handler` | `image_picker` 1.1.2 handles its own permission prompts on Android/iOS |
| `dio` | `http` already present transitively; Supabase client covers all network calls |
| `riverpod` / `bloc` / `provider` | Hard constraint — no state management refactor in v1.2 |
| `open_file` / `flutter_file_viewer` | `PdfPreview` from `printing` provides in-app PDF viewing |
| `whatsapp_share2` | Brittle platform-specific package; OS share sheet via `printing` reaches WhatsApp without it |

---

## Integration Notes

### PDF with Supabase Storage Images

Photos stored in Supabase Storage are accessed by downloading bytes:

```dart
final Uint8List imageBytes = await supabase.storage
    .from('checklist-images')
    .download('path/to/image.jpg');

// In PDF builder:
pw.Image(pw.MemoryImage(imageBytes), height: 120, fit: pw.BoxFit.contain)
```

Keep image size bounded (`height: 120` or similar) — `pdf` will not auto-wrap overflowing images and will throw a layout exception silently.

### PDF with Signature

```dart
// Export from signature widget
final Uint8List? sigBytes = await signatureController.toPngBytes();

// In PDF builder (bottom of report)
if (sigBytes != null)
  pw.Image(pw.MemoryImage(sigBytes), height: 80)
```

### Share Flow

```dart
final Uint8List pdfBytes = await doc.save();
await Printing.sharePdf(
  bytes: pdfBytes,
  filename: 'checklist_${checklistId}.pdf',
);
// Platform share sheet opens — user picks email, WhatsApp, Drive, etc.
```

No temp file write needed when using `Printing.sharePdf()` — it accepts raw bytes. Use `getTemporaryDirectory()` only if you need to save the PDF to the device for later retrieval.

### Android Permissions

`signature` and `pdf`/`printing` require no additional Android manifest permissions. `image_picker` already declared `READ_MEDIA_IMAGES` and `CAMERA` permissions for Phase 9.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| `pdf` version 3.11.3 | HIGH | Confirmed via pub.dev search showing 3.11.3 as latest, published ~April 2026 |
| `printing` version 5.14.2 | HIGH | Confirmed via libraries.io and pub.dev search results |
| `signature` version 9.0.0 | MEDIUM | Changelog confirms active maintenance and `Picture.toImage` fix; exact 9.0.0 version not directly confirmed in search results — verify with `flutter pub outdated` after add |
| `share_plus` exclusion rationale | HIGH | `Printing.sharePdf()` is documented to trigger platform share sheet; confirmed in multiple sources |
| No new packages for date/numeric/multichoice | HIGH | Flutter built-ins `showDatePicker`, `TextInputType.number`, `Checkbox` cover all cases |
| Syncfusion license risk | HIGH | Commercial license requirement explicitly documented on pub.dev license pages |

---

## Previous v1.1 Stack Decisions (Preserved)

From v1.1 research (still valid):

- `fl_chart` — bar/line/pie charts; only mature MIT-licensed option
- `image_picker` — camera + gallery; official Flutter plugin
- No `cached_network_image` needed — checklist photo thumbnails load inline during execution, not in a scrolling feed
- No `firebase_messaging` / `flutter_local_notifications` — notifications deferred to future milestone
- No email package in Flutter app — email delivery via Supabase Edge Functions (Resend API)

---

*Research: Stack additions for PrimeAudit v1.2 Checklist module — 2026-05-02*
