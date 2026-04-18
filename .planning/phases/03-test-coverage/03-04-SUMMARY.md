---
phase: 03-test-coverage
plan: "04"
subsystem: test
tags: [unit-test, models, company, app-user, perimeter, qual-03, qual-04]
dependency_graph:
  requires: []
  provides:
    - Company.fromMap unit tests (QUAL-03)
    - AppUser.fromMap unit tests (QUAL-03)
    - Perimeter.fromMap unit tests (QUAL-03)
    - Perimeter.buildTree hierarchy tests (QUAL-04)
  affects: []
tech_stack:
  added: []
  patterns:
    - fresh-instance helper _p() para evitar contaminação cruzada por mutação de children em Perimeter.buildTree
    - _baseMap() / _mapBase() factory para fixtures reutilizáveis por teste
key_files:
  created:
    - primeaudit/test/models/company_test.dart
    - primeaudit/test/models/app_user_test.dart
    - primeaudit/test/models/perimeter_test.dart
  modified: []
decisions:
  - Instâncias frescas via _p() em perimeter_test — buildTree muta children in-place, fixtures compartilhadas causariam contaminação cruzada entre testes
  - AppUser testado como equivalente de UserProfile do roadmap (ver 03-RESEARCH.md Pitfall 5)
metrics:
  duration: ~8min
  completed_date: "2026-04-18T15:45:41Z"
  tasks_completed: 3
  files_created: 3
  files_modified: 0
requirements:
  - QUAL-03
  - QUAL-04
---

# Phase 03 Plan 04: Model Unit Tests (Company, AppUser, Perimeter) Summary

**One-liner:** Testes unitários puros para Company.fromMap, AppUser.fromMap e Perimeter.fromMap + Perimeter.buildTree cobrindo hierarquias de 0-3 níveis, defaults, opcionais e caso orfão.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | company_test.dart — Company.fromMap | d8d13a8 | primeaudit/test/models/company_test.dart |
| 2 | app_user_test.dart — AppUser.fromMap | 5a96d0e | primeaudit/test/models/app_user_test.dart |
| 3 | perimeter_test.dart — Perimeter.fromMap + buildTree | ffcab98 | primeaudit/test/models/perimeter_test.dart |

## Test Results

| File | Tests | Status |
|------|-------|--------|
| test/models/company_test.dart | 10 | verde |
| test/models/app_user_test.dart | 12 | verde |
| test/models/perimeter_test.dart | 14 | verde |
| flutter test (suite completa) | 61+2 skipped | verde |

## Coverage Achieved

### Company.fromMap (QUAL-03)
- Campos obrigatórios: id, name, createdAt
- Campos opcionais null quando ausentes: cnpj, email, phone, address
- Campos opcionais populados quando presentes (4 casos)
- Defaults: active=true quando ausente, requires_perimeter=false quando ausente
- Valores explícitos: active=false, requiresPerimeter=true

### AppUser.fromMap (QUAL-03)
- Campos escalares: id, fullName, email, role, createdAt
- companyId: presente e null
- Join companies: companyName populado e null quando join ausente
- active: default=true e desativação explícita
- Getters derivados: canAccessAdmin (adm->true, auditor->false), isSuperOrDev (dev->true, adm->false)

### Perimeter.fromMap (QUAL-03)
- Campos obrigatórios: id, companyId, name, createdAt
- Campos opcionais null quando ausentes: parentId, description
- Campos opcionais populados quando presentes
- active: default=true e desativação explícita

### Perimeter.buildTree (QUAL-04)
- 0 níveis: lista vazia retorna raízes vazias
- 1 nível: raiz única sem filhos; 2 raízes coexistindo sem filhos
- 2 níveis: pai + filho único; pai + 3 filhos
- 3 níveis: neto aninhado dentro de filho dentro de raiz; floresta mista (2 raízes, filhos, 1 neto)
- Orfão: parentId referenciando id inexistente descartado silenciosamente

## Deviations from Plan

None - plano executado exatamente como escrito. Os 3 arquivos foram criados com o conteúdo exato especificado no plano. Suite completa permanece verde.

## Known Stubs

None.

## Threat Flags

None — arquivos criados são test-only, sem superfície de rede, auth ou PII real.

## Self-Check: PASSED

- primeaudit/test/models/company_test.dart: FOUND
- primeaudit/test/models/app_user_test.dart: FOUND
- primeaudit/test/models/perimeter_test.dart: FOUND
- commit d8d13a8: FOUND
- commit 5a96d0e: FOUND
- commit ffcab98: FOUND
- flutter test (suite completa): PASSED
