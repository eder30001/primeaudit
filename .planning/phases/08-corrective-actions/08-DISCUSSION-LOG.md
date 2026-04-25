# Phase 8: Corrective Actions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 08-corrective-actions
**Areas discussed:** Criação da ação

---

## Criação da Ação

### Entry Point

| Option | Description | Selected |
|--------|-------------|----------|
| Ícone sempre visível | Botão/ícone no card de cada pergunta, visível independente da resposta | |
| Só em não-conformes | O ícone aparece apenas quando a resposta indica não-conformidade | ✓ |
| Menu de contexto | Long press ou botão '...' no card abre opções incluindo 'Criar ação' | |

**User's choice:** Só em não-conformes
**Notes:** Mais focado; ícone aparece condicionalmente por tipo de resposta

---

### Formulário

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom sheet | Padrão já usado na tela de auditorias (_NewAuditSheet) | |
| Modal dialog | AlertDialog com campos | |
| Nova tela | Navigator.push para tela dedicada | ✓ |

**User's choice:** Nova tela
**Notes:** Mais espaço para o formulário; aceita sair temporariamente do contexto de execução

---

### Campos

| Option | Description | Selected |
|--------|-------------|----------|
| Título (obrigatório) | Descrição curta da ação | ✓ |
| Responsável (obrigatório) | Usuário do sistema | ✓ |
| Prazo (obrigatório) | Data limite | ✓ (após alerta de critério de sucesso) |
| Descrição/Observação (opcional) | Campo de texto livre para detalhes | ✓ |

**User's choice:** Título, responsável, prazo (todos obrigatórios) + descrição (opcional)
**Notes:** Prazo inicialmente não selecionado; adicionado após nota de inconsistência com critério de sucesso ACT-02

---

### Responsável

| Option | Description | Selected |
|--------|-------------|----------|
| Dropdown de usuários | Lista usuários da empresa via UserService | ✓ |
| Campo de texto livre | Auditor digita o nome | |

**User's choice:** Dropdown de usuários
**Notes:** Escolha importante para compatibilidade com notificações (Phase 11)

---

### Limiar de não-conformidade (scale_1_5)

| Option | Description | Selected |
|--------|-------------|----------|
| Score ≤ 2 | 1 e 2 são não-conformes | ✓ |
| Score ≤ 3 | Metade inferior + valor médio | |
| Claude decide | Usar limiar da lógica de conformidade existente | |

**User's choice:** Score ≤ 2

---

## Claude's Discretion

- Tela de listagem (layout, filtros, acesso via drawer)
- Fluxo de status CAPA (UX de transição, tela de detalhe, feedback de bloqueio)
- Badge de ações abertas (posição, definição de "aberta", estratégia de atualização)
- Migration da tabela `corrective_actions`
- Comportamento para tipos `selection` e `percentage`

## Deferred Ideas

- Notificações por atribuição → Phase 11
- Alertas de prazo vencendo → cron job, fora do escopo v1.1
- Filtro por pergunta vinculada → complexidade extra, próxima iteração
