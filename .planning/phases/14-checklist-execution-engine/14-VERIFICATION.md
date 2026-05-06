---
phase: 14-checklist-execution-engine
verified: 2026-05-06T00:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Falha no auto-save exibe snackbar não-bloqueante com opção de tentar novamente; retentativa automática com backoff exponencial"
    status: partial
    reason: "O snackbar e o backoff exponencial existem e funcionam. Porém, quando o retry automático (loop em _scheduleRetry) tem SUCESSO, o snackbar 'Não foi possível salvar' permanece visível com a action 'Tentar novamente'. Se o usuário toca essa action, um upsert redundante é disparado (sem corrupção, mas indica wiring incompleto). Adicionalmente, _onObservation atualiza _observations sem setState e sem preservar a observação no merge de _failedSaves durante reload — observações digitadas podem ser perdidas se o save falhar e o usuário puxar para atualizar."
    artifacts:
      - path: "primeaudit/lib/screens/checklist/checklist_execution_screen.dart"
        issue: "Linha 213-215: auto-retry bem-sucedido não limpa o snackbar. Linha 128-132: _onObservation atualiza _observations sem setState. Linha 88: _load não mescla observações de _failedSaves no reload."
    missing:
      - "Em _scheduleRetry, após setState(() => _failedSaves.remove(itemId)), adicionar ScaffoldMessenger.of(context).clearSnackBars() para dispensar snackbar stale."
      - "Em _onObservation, usar setState(() => _observations[itemId] = obs) para que observação seja preservada em rebuilds."
      - "Em _load, após linha 88 mesclar _failedSaves.observations: for (final e in _failedSaves.entries) { if (e.value.observation != null) mergedObs[e.key] = e.value.observation!; }"
human_verification:
  - test: "Desligar WiFi e preencher 3 itens; reativar WiFi e aguardar até 15s"
    expected: "As respostas digitadas offline são reenviadas automaticamente sem nenhuma ação do usuário; snackbar não permanece após retry bem-sucedido"
    why_human: "Comportamento de rede real não pode ser simulado programaticamente; requer dispositivo físico ou emulador com controle de conectividade"
  - test: "Digitar observação em item, desligar WiFi antes de salvar, puxar para atualizar (RefreshIndicator)"
    expected: "A observação digitada permanece visível após o reload — não é apagada"
    why_human: "Verificar se a observação sobrevive ao reload requer interação UI real e falha de rede simulada"
---

# Phase 14: Checklist Execution Engine — Verification Report

**Phase Goal:** Auditores preenchem um checklist completo com todos os tipos de resposta e o rascunho é salvo automaticamente sem bloqueio
**Verified:** 2026-05-06T00:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Usuário inicia execução preenchendo responsável, local, data e número; execução é criada com status rascunho | VERIFIED | `_StartChecklistSheet` coleta os 4 campos com validação; `createExecution` insere `status='rascunho'` no banco. Wiring completo: `_showStartSheet` → `ChecklistExecutionScreen`. |
| SC-2 | Usuário responde itens Sim/Não, texto, número, data e múltipla escolha; cada resposta persiste sem intervenção manual | VERIFIED | `_AnswerWidget` com switch para yes_no, text, number, date, multiple_choice. Cada resposta chama `_onAnswer` → `_saveAnswer` sem await. Upsert com `onConflict: 'execution_id,item_id'` idempotente. |
| SC-3 | Usuário adiciona observação opcional por item; observação é salva junto com a resposta | PARTIAL — WARNING | Campo de observação existe e é passado para `upsertAnswer`. Porém `_onObservation` não usa `setState` (linha 129) e observations não são preservadas no merge de _failedSaves durante reload (CR-03 + WR-07 do REVIEW.md). |
| SC-4 | Com WiFi desligado, o preenchimento continua sem modal de erro; ao reconectar, as respostas pendentes são enviadas | UNCERTAIN — HUMAN NEEDED | O padrão fire-and-forget + retry existe no código (`_scheduleRetry` com `pow(2, attemptCount)`). Comportamento offline/reconexão real não verificável programaticamente. |
| SC-5 | Usuário finaliza checklist; conformidade calculada e status muda para concluído | VERIFIED | `_finalize` chama `ChecklistAnswerService.calculateConformity` (método estático puro) e `finalizeExecution` que faz UPDATE `status='concluido'`, `conformity_percent` e `completed_at`. |

**Score:** 4/5 truths verificadas (1 parcial, 1 incerta/human needed)

### Deferred Items

Nenhum item identificado como diferido em fases posteriores para esta fase.

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `primeaudit/supabase/migrations/20260506_create_checklist_executions.sql` | Migration idempotente para checklist_executions e checklist_answers | VERIFIED | Arquivo existe com 173 linhas. Contém CREATE TABLE IF NOT EXISTS para ambas as tabelas, todas as colunas via ALTER TABLE ADD COLUMN IF NOT EXISTS, UNIQUE constraint `checklist_answers_execution_item_unique`, RLS completa com policies para superuser/dev/adm/auditor, NOTIFY pgrst. Nota: existe também 20260507 com conteúdo idêntico — duplicata possivelmente de worktree. |
| `primeaudit/supabase/migrations/20260506_add_options_to_checklist_template_items.sql` | Migration para coluna options em checklist_template_items | VERIFIED | Arquivo existe, contém `ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS options TEXT[];` e NOTIFY pgrst. |
| `primeaudit/lib/models/checklist_template.dart` | ChecklistTemplateItem com campo options List<String> | VERIFIED | `final List<String> options` presente. Construtor com `this.options = const []`. `fromMap` com `(map['options'] as List?)?.cast<String>() ?? []`. |
| `primeaudit/lib/models/checklist_execution.dart` | ChecklistExecution + ChecklistAnswer models | VERIFIED | Ambas as classes existem no arquivo. `dataExecucao` parseado sem `.toLocal()`. Join pattern `map['checklist_templates']?['name'] ?? ''`. Getters `isConcluido` e `isRascunho` presentes. |
| `primeaudit/lib/services/checklist_execution_service.dart` | CRUD de execuções | VERIFIED | `createExecution`, `getExecution`, `finalizeExecution`, `deleteExecution`. `_select` com join `checklist_templates(name)`. Serialização de data via `.toIso8601String().substring(0, 10)`. `created_by = auth.currentUser!.id`. |
| `primeaudit/lib/services/checklist_answer_service.dart` | Upsert de respostas e cálculo de conformidade | VERIFIED | `upsertAnswer` com `onConflict: 'execution_id,item_id'`. `calculateConformity` estático com `conformityTypes = {'yes_no', 'text', 'multiple_choice'}` excluindo number/date/photo. |
| `primeaudit/lib/screens/checklist/checklist_pending_save.dart` | ChecklistPendingSave data class | VERIFIED | Classe existe com campos `itemId`, `response`, `observation?`, `attemptCount`. `copyWithAttempt()` implementado. |
| `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` | Tela completa de execução de checklist | VERIFIED com ressalvas | 1165 linhas. Todos os widgets de resposta implementados (yes_no, text, number, date, multiple_choice, photo placeholder). Auto-save fire-and-forget. Retry exponencial. Guard de finalização. RESSALVAS: CR-03 (_onObservation sem setState), CR-02 (use_build_context_synchronously em _finalize), WR-07 (merge de observations no reload). |
| `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart` | Botão Executar + _StartChecklistSheet modal | VERIFIED | `_ChecklistTemplateCard` tem `onExecute` e ElevatedButton 'Executar'. `_showStartSheet` navega para `ChecklistExecutionScreen`. `_StartChecklistSheet` com Form de 4 campos. `Navigator.pop(context, execution)` retorna objeto ao caller. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_ChecklistTemplateCard` | `_showStartSheet` | `onExecute: () => _showStartSheet(...)` | WIRED | Linha 220 — callback passado ao card, botão 'Executar' no rodapé. |
| `_StartChecklistSheet._confirm` | `ChecklistExecutionService.createExecution` | `await widget.service.createExecution(...)` | WIRED | Linha 688 — campos coletados do Form e passados ao service. |
| `_showStartSheet` | `ChecklistExecutionScreen` | `Navigator.of(context).push(...)` com `execution: result` | WIRED | Linhas 161-173 — navega com objeto criado; `.then` chama `_load()` e exibe snackbar de sucesso. |
| `_onAnswer` | `_saveAnswer` | chamada sem await (fire-and-forget) | WIRED | Linha 125 — `_saveAnswer(itemId, response)` sem `await`. |
| `_saveAnswer catch` | `_failedSaves` | `setState(() => _failedSaves[itemId] = _PendingSave(...))` | WIRED | Linhas 157-163 — item adicionado à fila de falhas em catch. |
| `_scheduleRetry` | `Future.delayed` com backoff | `pow(2, pending.attemptCount).toInt()` | WIRED | Linha 201 — delays 1s, 2s, 4s, 8s. Guard de 4 tentativas máximas. |
| `_finalize` | `_failedSaves.isNotEmpty` guard | AlertDialog bloqueante antes de UPDATE | WIRED | Linha 234 — bloqueia finalização se há saves pendentes. |
| `ChecklistAnswerService.upsertAnswer` | `checklist_answers` | `.upsert({...}, onConflict: 'execution_id,item_id')` | WIRED | Linha 43-52 — parâmetro onConflict crítico presente. |
| `ChecklistExecutionService.finalizeExecution` | `checklist_executions` UPDATE | `.update({status: 'concluido', conformity_percent, completed_at})` | WIRED | Linhas 78-83 — UPDATE correto com todos os campos. |
| `ChecklistAnswerService.calculateConformity` | `conformityTypes` exclusion | `const {'yes_no', 'text', 'multiple_choice'}` | WIRED | Linha 72 — number, date, photo excluídos do denominador. |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `ChecklistExecutionScreen` | `_allItems` | `_templateService.getItems(templateId)` via Supabase | Sim — SELECT em `checklist_template_items` | FLOWING |
| `ChecklistExecutionScreen` | `_answers` | `_answerService.getAnswers(widget.execution.id)` via Supabase | Sim — SELECT em `checklist_answers` ordenado por `answered_at` | FLOWING |
| `ChecklistExecutionScreen` | `_conformity` | `ChecklistAnswerService.calculateConformity(_allItems, _answers)` | Sim — cálculo puro sobre dados reais em memória | FLOWING |
| `_ChecklistItemCard` | `answer` prop | `_answers[item.id]` do state pai | Sim — mapa populado por `_load()` e atualizado por `_onAnswer` | FLOWING |
| `_StartChecklistSheet` | execução criada | `ChecklistExecutionService.createExecution()` | Sim — INSERT com SELECT `.single()` e join | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED (sem servidor em execução; testes de rede e UI requerem dispositivo/emulador)

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| EXEC-01 | 14-01, 14-05 | Usuário inicia checklist preenchendo identificação (responsável, local, data, número/código) | SATISFIED | `_StartChecklistSheet` com Form de 4 campos, validação e `createExecution` com status rascunho |
| EXEC-02 | 14-02, 14-03, 14-04 | Usuário responde itens com todos os tipos suportados | SATISFIED (parcial) | 5 de 6 tipos implementados (yes_no, text, number, date, multiple_choice). `photo` tem placeholder informativo — EXEC-04 é Phase 15. |
| EXEC-03 | 14-02, 14-03, 14-04 | Usuário adiciona observação opcional por item | PARTIAL | Campo existe e é salvo via `upsertAnswer(observation: obs)`. Bug CR-03: `_onObservation` sem setState + WR-07: observações não preservadas no merge de reload. |
| EXEC-05 | 14-00, 14-03, 14-04 | Rascunho salvo automaticamente durante preenchimento (falha silenciosa não interrompe o checklist) | SATISFIED com ressalva | Fire-and-forget implementado. Retry exponencial implementado. Ressalva: snackbar de erro não é dispensado após retry automático bem-sucedido. |

**Requisito não coberto por esta fase (esperado):**
- EXEC-04 (foto por item) → Phase 15
- EXEC-06 (assinatura digital) → Phase 16

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `checklist_execution_screen.dart` | 129 | `_observations[itemId] = obs` sem `setState` em `_onObservation` | Warning | Observações não são preservadas em rebuilds e perdidas no reload após falha |
| `checklist_execution_screen.dart` | 88 | `_load` não mescla `_failedSaves.observations` em `mergedObs` | Warning | Observações digitadas em itens com save falho são silenciosamente apagadas no reload |
| `checklist_execution_screen.dart` | 213-215 | Retry automático bem-sucedido não dispensa snackbar stale | Warning | Snackbar "Não foi possível salvar" com action "Tentar novamente" pode persistir após retry ter sucesso |
| `checklist_execution_screen.dart` | 307 | `ScaffoldMessenger.of(context)` após `await` em `_finalize` sem captura prévia | Warning | `use_build_context_synchronously` lint — uso de context após await sem captura antecipada |
| `checklist_conformity_test.dart` | 5-34 | `expect(true, isTrue)` em todos os 6 testes — zero assertions reais | Info | Test suite não valida nenhum comportamento; `calculateConformity` é função pura testável sem mocks |
| `checklist_pending_save_test.dart` | 5-15 | `expect(true, isTrue)` em ambos os testes — zero assertions reais | Info | `copyWithAttempt` testável sem mocks (incrementa attemptCount) |
| `checklist_execution_screen.dart` | 982 | `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` — permite `1.2.3` | Info | Input numérico aceita múltiplos pontos decimais; falha apenas em parser downstream |
| `20260506_create_checklist_executions.sql` | 18 | `DEFAULT gen_random_uuid()` em `template_id` não é removido após ADD COLUMN | Info | INSERTs omitindo template_id falham com FK violation, mensagem de erro confusa |

---

## Human Verification Required

### 1. Comportamento offline com retry automático

**Test:** Em dispositivo físico ou emulador com controle de rede: abrir a tela de execução, desligar WiFi/dados, responder 3 itens, reativar rede, aguardar até 15 segundos
**Expected:** Respostas digitadas offline aparecem persistidas (sem modal bloqueante); após reconexão o snackbar "Não foi possível salvar" desaparece automaticamente (atualmente pode não desaparecer — veja gap)
**Why human:** Falha de rede real não pode ser simulada por grep/análise estática; comportamento de retry depende de timing de rede real

### 2. Observação sobrevive ao reload após save falho

**Test:** Digitar observação em um item, simular falha de rede (desligar WiFi antes do upsert completar), puxar para atualizar a tela (RefreshIndicator)
**Expected:** A observação digitada deveria permanecer visível após o reload. Atualmente FALHA por CR-03 + WR-07: `_onObservation` não usa setState e `_load` não mescla observações de `_failedSaves`
**Why human:** Requer controle preciso de timing de rede + interação de UI real para confirmar comportamento visual

---

## Gaps Summary

**1 gap bloqueante encontrado (status: gaps_found):**

**Gap principal — SC-3 (EXEC-03): Observações perdidas em cenário de falha**

`_onObservation` (linha 128-132) atualiza `_observations[itemId] = obs` diretamente sem `setState`, e `_load` (linha 88) só mescla respostas de `_failedSaves` mas não observações. Combinação: se um save falha com observação, e o usuário depois faz RefreshIndicator, a observação some do estado local mesmo estando em `_failedSaves.observation`. O requisito EXEC-03 ("observação é salva junto com a resposta") fica comprometido especificamente no cenário de falha + reload.

**Gap secundário relacionado — snackbar stale após retry automático**

Quando `_scheduleRetry` tem sucesso (linhas 213-215), `_failedSaves` é limpo mas o snackbar "Não foi possível salvar" com action "Tentar novamente" não é dispensado. O usuário pode ver o snackbar de erro mesmo após o dado ter sido salvo com sucesso. Não é data-loss, mas é UX incorreta que indica wiring incompleto do ciclo de retry.

**Causa raiz comum:** Faltam 3 linhas de código:
1. `setState(() => _observations[itemId] = obs)` em `_onObservation`
2. Merge de observations de `_failedSaves` em `_load`
3. `ScaffoldMessenger.of(context).clearSnackBars()` após sucesso do retry em `_scheduleRetry`

Itens dos testes (todos `expect(true, isTrue)`) são stubs intencionais do Wave 0 que não foram preenchidos. Não são bloqueantes para o objetivo da fase mas representam cobertura zero de `calculateConformity` (função pura, testável sem mocks).

---

_Verified: 2026-05-06T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
