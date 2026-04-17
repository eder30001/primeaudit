---
phase: 01-data-integrity
verified: 2026-04-16T00:00:00Z
status: human_needed
score: 4/6
overrides_applied: 0
human_verification:
  - test: "Ativar modo avião no dispositivo, abrir uma auditoria em execução, tocar em um chip de resposta qualquer e aguardar"
    expected: "Um SnackBar com texto 'Não foi possível salvar' e action button 'Tentar novamente' aparece na base da tela"
    why_human: "AuditAnswerService não é injetável em AuditExecutionScreen sem violar D-07; widget test completo exigiria Supabase.initialize com mock HTTP. DINT-01 requer verificação visual do snackbar em falha real de rede."
  - test: "Com modo avião ativo, tocar num chip de resposta e observar a UI imediatamente após o toque (antes do timeout)"
    expected: "O chip fica selecionado imediatamente (UI otimista), sem spinner ou indicador de 'pendente'. Snackbar de erro aparece depois quando o save falha."
    why_human: "DINT-02 — comportamento otimista precede o save; verificar que a resposta aparece selecionada antes do feedback de erro requer observação visual em tempo real. NOTA: o SC do ROADMAP pede 'indicador pendente (spinner ou ícone)' mas a decisão D-03 escolheu explicitamente UI otimista sem pendente — validar que o comportamento é aceitável para o auditor."
  - test: "Após snackbar de erro aparecer, tocar no action button 'Tentar novamente' com conexão restaurada"
    expected: "O save é disparado novamente e o item é salvo com sucesso (verificável via logs debugPrint ou via re-tentativa de finalização que não bloqueia mais)"
    why_human: "DINT-03 — retry manual; AuditAnswerService não é mockável sem DI. NOTA: o SC do ROADMAP diz 'tocar num item com falha' mas a implementação usa SnackBar action — validar que o mecanismo de retry via SnackBar é suficiente para o auditor."
---

# Phase 01: Data Integrity — Verification Report

**Phase Goal:** O auditor nunca perde uma resposta sem saber — falhas de save são visíveis e recuperáveis
**Verified:** 2026-04-16
**Status:** human_needed
**Re-verification:** No — verificação inicial

## Goal Achievement

### Contexto: Desvios Intencionais dos Success Criteria do ROADMAP

Os Success Criteria 1, 2 e 3 do ROADMAP.md descrevem indicadores visuais por item (borda vermelha, ícone, spinner). As decisões de implementação D-01, D-02 e D-03 em `01-CONTEXT.md` — documentadas **antes do planejamento** — escolheram deliberadamente uma abordagem diferente:

- D-01: SnackBar global em vez de borda/ícone por item
- D-02: Mensagem: "Não foi possível salvar"
- D-03: UI otimista sem spinner (resposta aparece selecionada imediatamente)

Esses desvios são **intencionais e pré-autorizados** pela fase de contexto. O SC 4 (catch vazio eliminado) está totalmente implementado. As verificações humanas abaixo validam se o comportamento alternativo entrega o mesmo valor para o auditor.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Quando `upsertAnswer` falha, o auditor vê indicador visual de erro | ? HUMAN | SC 1 do ROADMAP pede borda/ícone por item; implementação usa SnackBar (D-01). Código existe e é correto mas requer validação visual. |
| 2 | Enquanto uma resposta aguarda confirmação, há indicador "pendente" distinto | DESVIO INTENCIONAL | SC 2 pede spinner/ícone pendente; D-03 escolheu UI otimista sem indicador pendente. A resposta aparece selecionada imediatamente, sem estado intermediário. |
| 3 | O auditor pode re-salvar manualmente itens com falha sem reiniciar a tela | ? HUMAN | SC 3 diz "tocar num item"; implementação usa SnackBar action "Tentar novamente". Requer validação que o mecanismo alternativo satisfaz a necessidade. |
| 4 | O `catch` vazio em `audit_execution_screen.dart:228` não existe mais | ✓ VERIFIED | `grep "Falha silenciosa"` → 0 resultados. `catch (e)` com `debugPrint`, setState, `_showSaveError` e `_scheduleRetry` no lugar. |
| 5 | Retry automático com backoff exponencial roda em background | ✓ VERIFIED | `_scheduleRetry` implementado com `pow(2, attemptCount).toInt()`, delays 1s/2s/4s/8s, máximo 4 tentativas, guard `_retrying` Set, mounted checks. |
| 6 | Finalização é bloqueada quando há saves com falha | ✓ VERIFIED | `_finalize()` tem guard `if (_failedSaves.isNotEmpty)` mostrando AlertDialog "Respostas não salvas" com contagem e botão "Entendido". |

**Score:** 4/6 truths verificadas programaticamente (truths 4, 5, 6 + truth 2 documentada como desvio intencional pré-autorizado)

### Desvio Intencional Documentado (Truth 2)

A DINT-02 do REQUIREMENTS.md diz "App exibe indicador visual de resposta 'pendente' enquanto aguarda confirmação do servidor". A decisão D-03 de `01-CONTEXT.md` escolheu explicitamente **não implementar** esse indicador visual, adotando UI otimista em vez disso. Essa decisão foi tomada antes do planejamento e está documentada como decisão de design da fase.

Se o comportamento otimista sem spinner for considerado não-conforme com DINT-02, um override é necessário. Caso contrário, a verificação manual (item 2 abaixo) deve confirmar que o comportamento atual é aceitável para o auditor.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `primeaudit/lib/screens/pending_save.dart` | Classe pública PendingSave com `copyWithAttempt` | ✓ VERIFIED | Existe, 27 linhas, `class PendingSave`, construtor `const`, `copyWithAttempt()` incrementa `attemptCount`. Sem imports — pure Dart. |
| `primeaudit/lib/screens/audit_execution_screen.dart` | Fix completo: catch reescrito, _showSaveError, _scheduleRetry, guarda D-06 | ✓ VERIFIED | `import 'dart:math'`, `import 'pending_save.dart'`, `typedef _PendingSave = PendingSave`, campos `_failedSaves`/`_retrying`, métodos `_showSaveError`/`_scheduleRetry`, guard `_failedSaves.isNotEmpty` em `_finalize`. |
| `primeaudit/test/pending_save_test.dart` | 5 unit tests reais de PendingSave, 0 skip | ✓ VERIFIED | 5 testes com `expect(next.attemptCount, equals(3))`, nenhum `skip:`. |
| `primeaudit/test/audit_execution_save_error_test.dart` | 3 widget tests D-06 reais + 2 skip (DINT-01/03) | ✓ VERIFIED | `_FinalizeGuardTestHarness` implementado, 3 testes D-06 passando, 2 skip com pointer para `01-VALIDATION.md`. |
| `primeaudit/test/widget_test.dart` | Smoke test mínimo (sem contador inexistente) | ✓ VERIFIED | `test('smoke: flutter_test framework carrega', () { expect(1 + 1, equals(2)); })`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `audit_execution_screen.dart` | `pending_save.dart` | `import 'pending_save.dart'` | ✓ WIRED | Import relativo na linha 11, `typedef _PendingSave = PendingSave` usado em `_failedSaves` e em `_saveAnswer`. |
| `_saveAnswer` catch block | `_showSaveError` + `_scheduleRetry` | chamada direta na exceção | ✓ WIRED | `catch (e)` → `_showSaveError(itemId, response, obs)` + `_scheduleRetry(itemId)`. |
| `_finalize` guard | `_failedSaves.isNotEmpty` | early-return com AlertDialog | ✓ WIRED | Primeira instrução de `_finalize()` verifica `_failedSaves.isNotEmpty` e mostra `showDialog<void>` antes de retornar. |
| `pending_save_test.dart` | `pending_save.dart` | `import 'package:primeaudit/screens/pending_save.dart'` + instantiation | ✓ WIRED | Import presente, `PendingSave(itemId: 'item-1', ...)` instanciado em 5 testes. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `audit_execution_screen.dart` | `_failedSaves` | `_saveAnswer` catch block → `setState(() { _failedSaves[itemId] = _PendingSave(...); })` | Sim — populado por falha real de `upsertAnswer` | ✓ FLOWING |
| `audit_execution_screen.dart` | `_answers[itemId]` | `_onAnswer` → `setState(() => _answers[itemId] = response)` antes do save | Sim — UI otimista: estado setado antes do await | ✓ FLOWING |
| `_finalize` guard | `_failedSaves.length` | Lido diretamente do Map em memória | Sim — Map é a fonte de verdade da fila de retry | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Suíte de testes completa verde | `flutter test test/` | `+9 ~2: All tests passed!` (9 pass, 2 skip, 0 fail) | ✓ PASS |
| Análise estática sem erros | `flutter analyze lib/screens/audit_execution_screen.dart` | `No issues found!` | ✓ PASS |
| Catch silencioso eliminado | `grep "Falha silenciosa" audit_execution_screen.dart` | 0 correspondências | ✓ PASS |
| SnackBar com texto exato | `grep "'Não foi possível salvar'" audit_execution_screen.dart` | 1 correspondência (linha 278) | ✓ PASS |
| Action button retry | `grep "'Tentar novamente'" audit_execution_screen.dart` | 2 correspondências (linha 283 e linha 533 — a linha 533 é o botão "Tentar novamente" do estado de erro de carregamento, diferente) | ✓ PASS |
| Guard D-06 | `grep "Respostas não salvas" audit_execution_screen.dart` | 1 correspondência (linha 347) | ✓ PASS |
| Backoff exponencial | `grep "pow(2, pending.attemptCount).toInt()" audit_execution_screen.dart` | 1 correspondência (linha 306) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Descrição | Status | Evidência |
|-------------|------------|-----------|--------|-----------|
| DINT-01 | 01-01, 01-02, 01-03 | Auditor vê mensagem de erro quando save falha | ? NEEDS HUMAN | SnackBar com "Não foi possível salvar" implementado no código; verificação visual pendente. DINT-01 skip em `audit_execution_save_error_test.dart` com pointer para `01-VALIDATION.md`. |
| DINT-02 | 01-01, 01-02, 01-03 | App exibe indicador "pendente" enquanto aguarda confirmação | DESVIO INTENCIONAL | D-03 escolheu UI otimista sem indicador pendente. Resposta aparece selecionada imediatamente; snackbar de erro aparece após falha. `_answers[itemId]` setado em `_onAnswer` antes de `_saveAnswer`. |
| DINT-03 | 01-01, 01-02, 01-03 | Auditor pode re-salvar manualmente respostas que falharam | ? NEEDS HUMAN | Action button "Tentar novamente" no SnackBar chama `_saveAnswer` novamente. Código correto; verificação manual pendente. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/audit_execution_save_error_test.dart` | 141, 150 | `skip: true` (sem string explicativa) | ℹ️ Info | Intencionais — documentados em `01-VALIDATION.md`. Comentário inline explica razão. Não bloqueiam o objetivo da fase. |

Nenhum anti-pattern bloqueador encontrado. O `catch (_)` interno em `_scheduleRetry` (linha 323) é correto — é um retry interno onde a exceção é tratada incrementando `attemptCount` via `copyWithAttempt()`, não uma falha silenciosa.

### Human Verification Required

#### 1. DINT-01: SnackBar de erro aparece em falha de save

**Test:** Ativar modo avião no dispositivo, abrir uma auditoria em execução, tocar em qualquer chip de resposta e aguardar o timeout
**Expected:** SnackBar com texto "Não foi possível salvar" e action button "Tentar novamente" aparece na base da tela dentro de poucos segundos
**Why human:** AuditAnswerService não é injetável em AuditExecutionScreen sem violar D-07. Widget test completo exigiria inicialização real do Supabase ou mock HTTP — fora do escopo desta fase.

#### 2. DINT-02 / SC 2: Comportamento otimista vs indicador pendente

**Test:** Com modo avião ativo, tocar num chip de resposta e observar a resposta visual antes e depois do timeout de rede
**Expected (implementado):** O chip fica selecionado imediatamente após o toque (UI otimista, sem spinner). Snackbar de erro aparece depois quando o save falha.
**Expected (SC do ROADMAP):** SC 2 pede "indicador pendente (spinner ou ícone) distinto do estado salvo" — que NÃO foi implementado por decisão D-03.
**Why human:** Avaliar se a ausência de indicador pendente é aceitável para os auditores de campo. Se a UI otimista (chip selecionado + snackbar em falha) for suficiente, confirmar que DINT-02 está satisfeito com essa abordagem. Se não for suficiente, a decisão D-03 precisa ser revisada.

#### 3. DINT-03 / SC 3: Retry manual via SnackBar vs toque no item

**Test:** Após snackbar aparecer com falha de rede, tocar no action button "Tentar novamente" com conexão restaurada
**Expected (implementado):** O save é disparado novamente via `_saveAnswer`. Com conexão, o item é salvo e o SnackBar some.
**Expected (SC do ROADMAP):** SC 3 diz "tocar num item com falha" — mas a implementação usa SnackBar action (não toque no item).
**Why human:** Avaliar se o retry via SnackBar action é suficiente como mecanismo de re-save manual. Se o auditor precisar tocar no item diretamente para re-tentar (não via snackbar), isso representaria uma lacuna de UX.

### Gaps Summary

Não há gaps de implementação — o código implementa exatamente o que foi planejado nas decisões D-01 a D-07. Os itens pendentes são verificações humanas sobre se as decisões de design atendem aos Success Criteria do ROADMAP.

**Ponto crítico para decisão humana:** O ROADMAP.md descreve SC 1 e SC 2 com indicadores visuais por item (borda, ícone, spinner) que nunca foram implementados — foram substituídos por SnackBar global (D-01) e UI otimista sem pendente (D-03). Essas decisões foram documentadas no `01-CONTEXT.md` antes do planejamento, mas se os SCs do ROADMAP representam o contrato final, existem dois itens não satisfeitos literalmente:

- SC 1: "borda vermelha ou ícone" → substituído por SnackBar
- SC 2: "indicador pendente (spinner ou ícone)" → ausente (UI otimista)

Se essas decisões forem aceitas como válidas (o que parece ser a intenção dado que o REQUIREMENTS.md já marca DINT-01/02/03 como "Complete"), adicionar overrides ao frontmatter deste arquivo para as SCs 1 e 2.

---

_Verified: 2026-04-16T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
