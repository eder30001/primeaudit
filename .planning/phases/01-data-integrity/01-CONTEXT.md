# Phase 1: Data Integrity - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Corrigir a falha silenciosa de save em `audit_execution_screen.dart:228`. O auditor deve sempre saber quando uma resposta não foi salva, poder retentar, e o app não deve permitir finalizar uma auditoria com saves com falha. Nenhuma feature nova é adicionada — só correção de robustez na persistência de respostas.

</domain>

<decisions>
## Implementation Decisions

### Indicador Visual de Erro
- **D-01:** Usar apenas snackbar para notificar falha de save (sem borda/ícone no chip da resposta). O auditor vê a mensagem na base da tela.
- **D-02:** Mensagem do snackbar: `"Não foi possível salvar"` — curta, sem jargão técnico.

### Estado Pendente
- **D-03:** UI otimista — a resposta aparece selecionada imediatamente após o toque, sem nenhum spinner. Indicador só aparece se o save falhar (D-01). Não implementar estado "pendente" visual.

### Mecanismo de Retry
- **D-04:** O snackbar de erro inclui um action button **"Tentar novamente"** que dispara `_saveAnswer` novamente para o item com falha.
- **D-05:** Implementar fila de retry com exponential backoff — saves com falha ficam na fila e são reprocessados automaticamente quando a conexão for restaurada.

### Escopo da Correção
- **D-06:** Finalização **bloqueada** se houver saves com falha na fila — ao tocar "Finalizar", se `_failedSaves` não estiver vazia, exibir dialog de bloqueio informando quantas respostas falharam antes de permitir continuar.
- **D-07:** Escopo restrito ao `_saveAnswer` em `audit_execution_screen.dart` — não revisar outros catch blocks (cancelar, encerrar) nesta fase. Esses já exibem snackbar de erro.

### Claude's Discretion
- Estrutura interna da fila de retry (Map, Queue, ou lista de pending items) — Claude decide
- Estratégia de backoff (delays: 1s, 2s, 4s, ou outro) — Claude decide
- Se manter fila em memória ou persistir entre navegações de tela — Claude decide
- Como identificar o item na fila para o snackbar action button (por itemId) — Claude decide

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Arquivo com o bug
- `primeaudit/lib/screens/audit_execution_screen.dart` — linhas 219-231 (`_saveAnswer` com catch silencioso em linha 228). Também verificar `_finalize()` a partir da linha 235 para implementar o bloqueio (D-06).

### Serviço de respostas
- `primeaudit/lib/services/audit_answer_service.dart` — método `upsertAnswer()` que é chamado pelo `_saveAnswer`. Verificar quais exceções pode lançar.

### Padrões de UI existentes
- `primeaudit/lib/core/app_theme.dart` — `AppColors.error` e demais cores para consistência visual do snackbar
- `primeaudit/lib/screens/audit_execution_screen.dart` — método `_snack()` já existente para exibição de snackbars (verificar assinatura e comportamento)

No external specs — decisions fully captured above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_snack()` — método privado já existente em `audit_execution_screen.dart` para exibir SnackBars. Deve ser usado/estendido para exibir o snackbar de erro com action button de retry.
- `AppColors.error` — cor vermelha já definida e usada em toda a tela. Usar para o snackbar de erro.
- `_observations` (`Map<String, String>`) — padrão de rastrear estado por `itemId`. Usar mesmo padrão para `_failedSaves` (Map ou Set de itemIds com save pendente).

### Established Patterns
- Estado por item rastreado em Maps privados (`_observations`, `_answers`)
- `setState()` para atualizar UI após mudança de estado
- Calls assíncronas a services via `await` dentro de métodos `Future<void>`
- Snackbar com `ScaffoldMessenger` para feedback ao usuário

### Integration Points
- `_saveAnswer(itemId, response)` — ponto único de integração. Toda a correção começa aqui.
- `_finalize()` — ponto onde o bloqueio de finalização (D-06) deve ser inserido como guarda inicial.

</code_context>

<specifics>
## Specific Ideas

- O snackbar deve incluir action button "Tentar novamente" (D-04) que chama `_saveAnswer(itemId, response)` com os valores que falharam — portanto a fila precisa guardar tanto o `itemId` quanto o `response` e `observation`.
- A fila de retry com backoff (D-05) deve operar em background enquanto o auditor continua respondendo outros itens.
- O bloqueio de finalização (D-06) deve mostrar quantas respostas falharam: ex. `"2 respostas não foram salvas. Resolva as falhas antes de finalizar."`.

</specifics>

<deferred>
## Deferred Ideas

- Modo offline completo com sync — nova feature, fora do escopo desta milestone
- Indicador de conectividade de rede na tela — não foi pedido, Claude pode decidir se é útil
- Persistência da fila de retry entre fechamentos do app — complexidade alta, defer

</deferred>

---

*Phase: 01-data-integrity*
*Context gathered: 2026-04-16*
