---
phase: 14
phase_slug: checklist-execution-engine
date: 2026-05-05
---

# Phase 14: Checklist Execution Engine — Validation Strategy

## Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK — sem pacotes extras) |
| Run quick | `flutter test test/checklist_conformity_test.dart` |
| Run suite | `cd primeaudit && flutter test` |
| Analyze | `cd primeaudit && flutter analyze` |

## Requirements → Test Map

| Req ID | Comportamento testável | Tipo | Arquivo de teste | Wave |
|--------|----------------------|------|-----------------|------|
| EXEC-01 | `createExecution` retorna objeto com `status = 'rascunho'` e campos preenchidos | unit (mock) | `test/checklist_execution_service_test.dart` | Wave 0 |
| EXEC-02 | `upsertAnswer` salva resposta `yes_no`, `text`, `number`, `date`, `multiple_choice` | unit (mock) | `test/checklist_answer_service_test.dart` | Wave 0 |
| EXEC-03 | `upsertAnswer` com `observation` não-nulo persiste ambos os campos | unit (mock) | `test/checklist_answer_service_test.dart` | Wave 0 |
| EXEC-05 | Falha no `upsertAnswer` não propaga exceção para a tela — capturada pelo padrão `_PendingSave` | unit (mock) | `test/checklist_pending_save_test.dart` | Wave 0 |
| SC-5 | `calculateConformity` exclui `number` e `date` do denominador; `yes_no='no'` é não conforme | unit | `test/checklist_conformity_test.dart` | Wave 0 |

## Wave 0 — Stubs necessários

Criar antes da execução das waves de implementação:

- [ ] `primeaudit/test/checklist_execution_service_test.dart`
- [ ] `primeaudit/test/checklist_answer_service_test.dart`
- [ ] `primeaudit/test/checklist_conformity_test.dart`
- [ ] `primeaudit/test/checklist_pending_save_test.dart`

## Sampling Strategy

| Momento | Comando | Escopo |
|---------|---------|--------|
| Por task concluída | `flutter test test/checklist_conformity_test.dart` | Conformidade (puro, rápido) |
| Por wave completa | `flutter test` | Suite completa |
| Phase gate | `flutter analyze && flutter test` | Zero erros + suite verde |

## Acceptance Gate

Para a fase ser marcada como concluída:
1. `flutter analyze` — zero erros, zero warnings
2. `flutter test` — todos os testes passam (incluindo os 4 arquivos Wave 0)
3. `supabase db push` executado — migrations aplicadas no banco remoto
4. Fluxo manual end-to-end verificado: selecionar template → iniciar execução → preencher todos os tipos → finalizar → ver conformidade
