# Phase 1: Data Integrity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 01-data-integrity
**Areas discussed:** Indicador visual de erro, Estado pendente, Mecanismo de retry, Escopo da correção

---

## Indicador Visual de Erro

| Option | Description | Selected |
|--------|-------------|----------|
| Borda/ícone no próprio item | Chip/botão da resposta ganha borda vermelha + ícone de aviso | |
| Snackbar + ícone no item | Snackbar na base + item marcado | |
| Só snackbar | Toast na base da tela com mensagem de erro | ✓ |

**User's choice:** Só snackbar
**Notes:** Preferência por feedback centralizado, sem poluir visualmente os chips de resposta.

| Option | Description | Selected |
|--------|-------------|----------|
| Simples: 'Não foi possível salvar' | Curto, sem jargão técnico | ✓ |
| Com instrução de retry | 'Falha ao salvar — toque para tentar novamente' | |
| Sem texto, só ícone | Só ícone de aviso no chip | |

**User's choice:** "Não foi possível salvar"

---

## Estado Pendente

| Option | Description | Selected |
|--------|-------------|----------|
| Não — só mostrar erro se falhar | UI otimista, sem spinner intermediário | ✓ |
| Sim — spinner discreta no item | CircularProgressIndicator no chip | |
| Sim — indicador global no AppBar | LinearProgressIndicator no topo | |

**User's choice:** UI otimista — não mostrar estado pendente, só indicar se falhar.

---

## Mecanismo de Retry

| Option | Description | Selected |
|--------|-------------|----------|
| Retoque no mesmo item | Tocar no chip já selecionado reexecuta _saveAnswer | |
| Botão 'Tentar novamente' no snackbar | Action button no SnackBar de erro | ✓ |
| Botão flutuante 'Salvar pendentes' | FAB ou botão no AppBar para saves pendentes | |

**User's choice:** Botão "Tentar novamente" no snackbar.

| Option | Description | Selected |
|--------|-------------|----------|
| Não — só retry manual | Sem monitorar conectividade | |
| Sim — auto-retry uma vez | Retenta uma vez com delay fixo | |
| Sim — fila de retry com backoff | Fila + exponential backoff automático | ✓ |

**User's choice:** Fila de retry com exponential backoff.

---

## Escopo da Correção

| Option | Description | Selected |
|--------|-------------|----------|
| Alertar e permitir continuar | Dialog de aviso, auditor decide | |
| Bloquear finalização | Não permite finalizar com saves pendentes | ✓ |
| Finalizar normalmente | Sem verificação | |

**User's choice:** Bloquear finalização enquanto houver saves com falha.

| Option | Description | Selected |
|--------|-------------|----------|
| Só o _saveAnswer | Foco no problema crítico | ✓ |
| Todos os catchs na tela | Revisão completa de error handling | |

**User's choice:** Escopo restrito ao `_saveAnswer`.

---

## Claude's Discretion

- Estrutura interna da fila de retry (Map, Queue, lista)
- Estratégia de backoff (delays específicos)
- Se persistir fila entre navegações ou só em memória
- Como identificar item para o snackbar action button

## Deferred Ideas

- Modo offline completo com sync — nova feature, fora do escopo
- Indicador de conectividade de rede na tela
- Persistência da fila de retry entre fechamentos do app
