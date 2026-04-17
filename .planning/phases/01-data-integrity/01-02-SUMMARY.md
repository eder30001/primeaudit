---
phase: 01-data-integrity
plan: "02"
subsystem: audit-execution
tags: [flutter, retry, error-handling, snackbar, audit-execution]
dependency_graph:
  requires:
    - primeaudit/lib/screens/pending_save.dart (Plan 01 — PendingSave class)
  provides:
    - primeaudit/lib/screens/audit_execution_screen.dart (fix completo Wave 1)
  affects:
    - primeaudit/test/audit_execution_save_error_test.dart (Plan 03 ativará esses testes)
tech_stack:
  added: []
  patterns:
    - Fila de retry em memória por itemId com Map<String, _PendingSave>
    - Backoff exponencial via pow(2, attemptCount) com limite _maxAutoRetryAttempts = 4
    - ScaffoldMessenger capturado antes de async gap para uso seguro em closures
    - Guard mounted antes de qualquer setState em métodos async
key_files:
  created: []
  modified:
    - primeaudit/lib/screens/audit_execution_screen.dart
decisions:
  - "clearSnackBars() usado (não hideCurrentSnackBar) — elimina acúmulo de snackbars em falhas sucessivas conforme RESEARCH.md Open Question #1"
  - "_scheduleRetry usa Set _retrying como mutex em memória para evitar loops concorrentes por itemId"
  - "catch amplo (catch e) no _saveAnswer — captura PostgrestException, ClientException, SocketException, TimeoutException sem discriminar tipo"
metrics:
  duration: "156s"
  completed: "2026-04-17T22:22:35Z"
  tasks_completed: 3
  files_created: 0
  files_modified: 1
requirements: [DINT-01, DINT-02, DINT-03]
---

# Phase 01 Plan 02: Fix Completo — _saveAnswer Retry e Guarda D-06 Summary

**One-liner:** Bug raiz corrigido — catch silencioso substituído por fila de retry em memória com backoff exponencial, snackbar de erro com action "Tentar novamente", e bloqueio de finalização quando há saves pendentes.

## What Was Built

### Diff resumido de `audit_execution_screen.dart` por região

| Região | Mudança |
|--------|---------|
| Bloco de imports (linhas 1–10) | +2 linhas: `import 'dart:math'` e `import 'pending_save.dart'` |
| Topo do arquivo (antes da class) | +4 linhas: `typedef _PendingSave = PendingSave` com comentário |
| `_AuditExecutionScreenState` — campos | +6 linhas: `_maxAutoRetryAttempts`, `_failedSaves`, `_retrying` |
| `_saveAnswer` (linhas 219-231 originais) | -11 linhas removidas, +32 inseridas — reescrita completa |
| Após `_saveAnswer` | +55 linhas: métodos `_showSaveError` e `_scheduleRetry` novos |
| `_finalize` — topo | +23 linhas: guarda D-06 inserida antes do `showDialog<bool>` existente |

### Conteúdo final de `_saveAnswer`

```dart
Future<void> _saveAnswer(
  String itemId,
  String response, {
  String? observation,
}) async {
  final obs = observation ?? _observations[itemId];
  try {
    await _answerService.upsertAnswer(
      auditId: widget.audit.id,
      templateItemId: itemId,
      response: response,
      observation: obs,
    );
    if (_failedSaves.containsKey(itemId) && mounted) {
      setState(() => _failedSaves.remove(itemId));
    }
  } catch (e) {
    debugPrint('[_saveAnswer] itemId=$itemId erro: $e');
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

### Conteúdo final da guarda D-06 em `_finalize`

```dart
Future<void> _finalize() async {
  // ── Guarda D-06: bloqueia finalização se há respostas com falha ───────
  if (_failedSaves.isNotEmpty) {
    final count = _failedSaves.length;
    final respostas = count > 1 ? 'respostas' : 'resposta';
    final verbo = count > 1 ? 'foram salvas' : 'foi salva';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respostas não salvas'),
        content: Text(
          '$count $respostas não $verbo. '
          'Resolva as falhas antes de finalizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return; // NÃO prossegue para o dialog de confirmação de finalização
  }
  // ... resto do _finalize original inalterado
```

### Resultado de verificações

```
flutter analyze lib/screens/audit_execution_screen.dart
→ No issues found! (ran in 2.4s)

flutter test test/
→ 00:00 +1 ~5: All tests passed!
   1 passing (smoke), 5 skipped (scaffolds Wave 1 e 2)
   Exit code 0
```

## Deviations from Plan

None — plano executado exatamente como escrito.

A única questão aberta do RESEARCH.md (Open Question #1: `clearSnackBars()` vs `hideCurrentSnackBar()`) foi resolvida com `clearSnackBars()` conforme o padrão recomendado — elimina todos os snackbars acumulados, evitando fila de mensagens de erro em falhas sucessivas rápidas.

## Commits

| Hash | Tipo | Descrição |
|------|------|-----------|
| 71cea7e | feat | Adicionar imports, alias _PendingSave e campos de estado (Task 1) |
| 8ccb268 | feat | Reescrever _saveAnswer e implementar _showSaveError/_scheduleRetry (Task 2) |
| b6d4088 | feat | Inserir guarda D-06 no _finalize bloqueando com falhas pendentes (Task 3) |

## Known Stubs

Nenhum. Todas as funcionalidades implementadas estão funcionais (não são placeholders). Os stubs existentes são dos scaffolds de teste do Plan 01 — não introduzidos por este plano.

## Threat Flags

Nenhum. Conforme threat model do plano:
- `debugPrint` com detalhes de exceção: aceito (silenciado em release builds do Flutter)
- Retry loop com backoff: mitigado via `_maxAutoRetryAttempts = 4` e Set `_retrying`
- Nenhum novo endpoint de rede, auth ou acesso a dados introduzido

## Self-Check: PASSED

- [x] `primeaudit/lib/screens/audit_execution_screen.dart` modificado
- [x] `grep -c "// Falha silenciosa"` retorna `0`
- [x] `grep -c "import 'dart:math';"` retorna `1`
- [x] `grep -c "import 'pending_save.dart';"` retorna `1`
- [x] `grep -c "typedef _PendingSave = PendingSave;"` retorna `1`
- [x] `grep -c "_failedSaves"` encontra declaração e usos
- [x] `grep -c "'Não foi possível salvar'"` retorna `1`
- [x] `grep -c "'Tentar novamente'"` retorna >= 1
- [x] `grep -c "'Respostas não salvas'"` retorna `1`
- [x] `grep -c "'Entendido'"` retorna `1`
- [x] Commit 71cea7e existe
- [x] Commit 8ccb268 existe
- [x] Commit b6d4088 existe
- [x] `flutter analyze`: No issues found!
- [x] `flutter test test/`: All tests passed! (exit 0)
