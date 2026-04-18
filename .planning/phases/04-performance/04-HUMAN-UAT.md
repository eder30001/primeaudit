---
status: partial
phase: 04-performance
source: [04-VERIFICATION.md]
started: 2026-04-18T00:00:00Z
updated: 2026-04-18T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. RLS compatibility — batch upsert on template_items
expected: Authenticate as `adm` or `superuser` and issue a batch upsert to `template_items` via the PostgREST API or Supabase Dashboard with valid existing IDs from their company. Expected: HTTP 200/204, `order_index` values updated, no RLS violation (403/42501).
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
