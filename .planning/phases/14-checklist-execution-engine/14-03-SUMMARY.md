---
phase: 14-checklist-execution-engine
plan: "03"
subsystem: services
tags: [services, dart, checklist, execution, upsert, conformity, auto-save]
dependency_graph:
  requires:
    - "14-02 (ChecklistExecution model, ChecklistTemplateItem.options)"
  provides:
    - ChecklistExecutionService (primeaudit/lib/services/checklist_execution_service.dart)
    - ChecklistAnswerService (primeaudit/lib/services/checklist_answer_service.dart)
  affects:
    - 14-04 (ChecklistExecutionScreen usa ambos os services)
    - 14-05 (wiring usa ChecklistExecutionService.createExecution)
tech_stack:
  added: []
  patterns:
    - "upsert onConflict: 'execution_id,item_id' — idempotente, sem 409"
    - "calculateConformity static — sem I/O, puro Dart, clamp(0.0, 100.0)"
    - "conformityTypes = {yes_no, text, multiple_choice} — number/date/photo excluidos do denominador"
    - "getAnswers retorna List<Map<String, dynamic>> — sem modelo intermediario"
    - "created_by obtido de auth.currentUser!.id — nao recebido como parametro (T-14-09)"
    - "data_execucao serializado via toIso8601String().substring(0, 10) — sem intl, sem timezone"
key_files:
  created:
    - primeaudit/lib/services/checklist_execution_service.dart
    - primeaudit/lib/services/checklist_answer_service.dart
  modified: []
decisions:
  - "getAnswers retorna raw maps (List<Map>) em vez de List<ChecklistAnswer> — screen mapeia diretamente para _answers[itemId], evitando conversao intermediaria desnecessaria"
  - "calculateConformity e static — sem round-trip de rede, calculo puro no cliente antes de finalizeExecution"
  - "companyId recebido como parametro em createExecution — desacoplado de CompanyContextService, responsabilidade do caller"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-06"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 14 Plan 03: Checklist Services Summary

ChecklistExecutionService (CRUD de execucoes com join) e ChecklistAnswerService (upsert idempotente com onConflict + calculateConformity estatico excluindo number/date do denominador).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Criar ChecklistExecutionService | 1511614 | primeaudit/lib/services/checklist_execution_service.dart |
| 2 | Criar ChecklistAnswerService com calculateConformity | 6563397 | primeaudit/lib/services/checklist_answer_service.dart |

## What Was Built

**Task 1 — ChecklistExecutionService**

Criado `primeaudit/lib/services/checklist_execution_service.dart` com quatro metodos:

- `createExecution`: INSERT em `checklist_executions` com `status='rascunho'`. Serializa `data_execucao` como `'yyyy-MM-dd'` via `.toIso8601String().substring(0, 10)` (sem dependencia de `intl`, sem conversao de timezone). `created_by` obtido de `_client.auth.currentUser!.id` — nao recebido como parametro (mitigacao T-14-09). Retorna `ChecklistExecution.fromMap(result)` com `templateName` populado via join `checklist_templates(name)`.

- `getExecution(id)`: SELECT com mesmo `_select` constante, retorna `ChecklistExecution` tipado.

- `finalizeExecution({id, conformityPercent})`: UPDATE com `status='concluido'`, `conformity_percent` e `completed_at=DateTime.now()`.

- `deleteExecution(id)`: DELETE — cascade de `checklist_answers` gerenciado pelo banco via `ON DELETE CASCADE`.

`_select` constante com join `checklist_templates(name)` garante que `templateName` sempre vem populado nas operacoes de leitura.

**Task 2 — ChecklistAnswerService**

Criado `primeaudit/lib/services/checklist_answer_service.dart` com tres metodos:

- `getAnswers(executionId)`: SELECT em `checklist_answers` ordenado por `answered_at`. Retorna `List<Map<String, dynamic>>` — sem modelo intermediario. Screen mapeia diretamente: `_answers[row['item_id']] = row['response']`.

- `upsertAnswer({executionId, itemId, response, observation})`: UPSERT em `checklist_answers` com `onConflict: 'execution_id,item_id'`. Este parametro e critico — sem ele, o banco retorna 409 na segunda resposta ao mesmo item (violacao da UNIQUE constraint). Mecanismo central do auto-save silencioso (EXEC-05).

- `calculateConformity(items, answers)` — estatico, sem I/O:
  - `conformityTypes = {'yes_no', 'text', 'multiple_choice'}` — `number`, `date`, `photo` excluidos do denominador (decisao STATE.md v1.2)
  - Retorna `100.0` quando `eligible.isEmpty` (evita divisao por zero)
  - Itens sem resposta (`ans == null || ans.isEmpty`) entram no denominador mas nao no numerador (continue)
  - `yes_no`: apenas `'yes'` conta como conforme; `'no'` entra no denominador
  - `text` e `multiple_choice`: qualquer string nao-vazia conta como conforme
  - Resultado clampado em `[0.0, 100.0]`

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| `class ChecklistExecutionService` count = 1 | PASS |
| `checklist_templates(name)` presente no _select | PASS |
| `toIso8601String.*substring(0, 10)` presente | PASS |
| `class ChecklistAnswerService` count = 1 | PASS |
| `onConflict: 'execution_id,item_id'` presente | PASS |
| `conformityTypes = {yes_no, text, multiple_choice}` presente | PASS |

## Known Stubs

None — services puros sem dados mockados ou placeholders.

## Threat Surface Scan

Nenhum novo endpoint de rede ou path de auth introduzido alem do que o plano previa.

Mitigacoes do threat register aplicadas:

- **T-14-09 (mitigate):** `created_by` obtido de `_client.auth.currentUser!.id` em `createExecution` — nao recebido como parametro, impedindo que o caller injete um userId forjado. RLS `WITH CHECK (created_by = auth.uid())` adiciona segunda camada no banco.
- **T-14-07 (accept):** `response TEXT` — qualquer string incluindo vazia e aceita pelo banco; validacao de "nao vazio antes de upsert" e responsabilidade da screen.
- **T-14-08 (accept):** `calculateConformity` e metodo estatico puro; recebe apenas dados ja em memoria da screen; conformidade calculada no cliente.

## Self-Check: PASSED

- [x] `primeaudit/lib/services/checklist_execution_service.dart` existe e criado
- [x] `primeaudit/lib/services/checklist_answer_service.dart` existe e criado
- [x] Commit 1511614 existe (Task 1)
- [x] Commit 6563397 existe (Task 2)
