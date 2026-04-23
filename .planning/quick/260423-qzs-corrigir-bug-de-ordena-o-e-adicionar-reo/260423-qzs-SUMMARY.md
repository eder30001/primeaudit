---
phase: quick-260423-qzs
plan: "01"
subsystem: templates
tags: [bug-fix, drag-drop, reorder, upsert, mounted-guard]
dependency_graph:
  requires: []
  provides: [reorderSections, defaultToNull-fix, section-drag-drop]
  affects: [template_builder_screen, audit_template_service]
tech_stack:
  added: []
  patterns: [ReorderableListView, ReorderableDragStartListener, batch-upsert]
key_files:
  modified:
    - primeaudit/lib/services/audit_template_service.dart
    - primeaudit/lib/screens/templates/template_builder_screen.dart
decisions:
  - "defaultToNull: false é obrigatório em batch upserts parciais (apenas id + order_index) para não violar NOT NULL constraints"
  - "ReorderableListView de seções usa buildDefaultDragHandles: false com ReorderableDragStartListener explícito no header"
metrics:
  duration_seconds: 79
  completed_date: "2026-04-23"
  tasks_completed: 2
  files_modified: 2
---

# Quick Task 260423-qzs: Corrigir Bug de Ordenação e Adicionar Reordenação de Seções — Summary

**One-liner:** Bug fix de `defaultToNull` no upsert batch + drag & drop de seções com `ReorderableListView` e handle explícito.

## Changes Applied

### Task 1 — `audit_template_service.dart` (commit `bbc0000`)

1. `reorderItems`: substituído `upsert(payload)` por `upsert(payload, defaultToNull: false)` — impede que o PostgREST tente setar NULL nas colunas não incluídas no payload (question, response_type, etc.), eliminando a violação de constraint NOT NULL.
2. Novo método `reorderSections`: mesmo padrão de `reorderItems`, aponta para `template_sections`, usa `defaultToNull: false`.

### Task 2 — `template_builder_screen.dart` (commit `0afdd83`)

1. `_persistSectionOrder` catch: `_load()` → `if (mounted) _load()`.
2. `_persistUnsectionedOrder` catch: `_load()` → `if (mounted) _load()`.
3. Novo método `_persistSectionsOrder`: chama `_service.reorderSections(...)` com guard `if (mounted) _load()` no catch.
4. `_buildSection` recebe novo parâmetro `int sectionIndex`; `ReorderableDragStartListener(index: sectionIndex)` adicionado como primeiro filho do Row do cabeçalho.
5. Seções renderizadas dentro de `ReorderableListView` (`shrinkWrap: true`, `NeverScrollableScrollPhysics`, `buildDefaultDragHandles: false`) substituindo o flat `.map((s) => _buildSection(s))`.

## Verification

```
dart analyze lib/screens/templates/template_builder_screen.dart lib/services/audit_template_service.dart
→ No issues found!

dart analyze lib/ | grep -E "error|warning"
→ (no output — zero errors)
```

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `bbc0000` exists in git log
- `0afdd83` exists in git log
- `primeaudit/lib/services/audit_template_service.dart` modified and committed
- `primeaudit/lib/screens/templates/template_builder_screen.dart` modified and committed
- `dart analyze` passes with no issues
