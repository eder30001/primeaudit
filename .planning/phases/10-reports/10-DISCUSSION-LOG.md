# Phase 10: Calendar Dashboard - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-29
**Phase:** 10-reports (Calendar Dashboard — escopo original de Relatórios removido)
**Areas discussed:** Redirecionamento de escopo, Calendário no Dashboard, Hotfixes

---

## Redirecionamento de Escopo

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Manter Relatórios (REP-01/02/03/04) | Filtros por data e template, lista e gráfico | |
| Calendário no Dashboard | Novo escopo: calendário mensal interativo no dashboard | ✓ |

**Decisão do usuário:** Remover Relatórios do escopo e do menu. Phase 10 entrega o Calendário de Auditorias no Dashboard.
**Notas:** Usuário considerou que relatórios não fazem sentido no app neste momento.

---

## Escopo da Phase 10

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Calendário + Bug fix + Excluir tipo | 3 itens juntos na mesma fase | |
| Calendário no Dashboard (apenas) | Phase 10 foca só no calendário; bugs viram hotfix separado | ✓ |

**Decisão do usuário:** Phase 10 = Calendário. Bug do responsável e exclusão de tipo = hotfix antes da fase.

---

## Urgência do Bug (Responsável na Ação Corretiva)

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Corrigir antes do calendário | Hotfix imediato | ✓ |
| Pode esperar | Entrar no Phase 10 ou próxima sessão | |

**Decisão do usuário:** Corrigir o bug com urgência, antes de planejar o Phase 10.

---

## Posição do Calendário no Dashboard

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Abaixo dos KPI cards | Calendário embaixo dos 4 cards existentes | ✓ |
| Substitui os KPI cards | Calendário no topo, cards somem | |
| Nova aba/tab | Dashboard e Calendário em tabs separadas | |

**Decisão do usuário:** Abaixo dos KPI cards, substituindo placeholder de atividade recente.

---

## Indicadores de Status por Dia

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| 3 indicadores | Novas + Atrasadas + Concluídas com cores distintas | ✓ |
| 2 indicadores | Pendentes + Concluídas | |
| Claude decide | Mapeamento por conta do Claude | |

**Decisão do usuário:** 3 indicadores — Novas (rascunho + em_andamento), Atrasadas (atrasada), Concluídas (concluida).

---

## Campo de Data no Calendário

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| created_at | Data de criação — sempre preenchida | |
| deadline | Prazo da auditoria — pode ser nulo | |

**Decisão do usuário:** deadline como campo principal; auditorias sem deadline usam created_at como fallback.

---

## Hotfix: Excluir Tipo de Auditoria

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Hotfix rápido junto com o bug | Antes do Phase 10 | ✓ |
| Fase separada após o calendário | | |

**Decisão do usuário:** Hotfix junto com o bug do responsável.

---

## Auditorias Sem Prazo

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Só com prazo aparecem | Auditorias sem deadline não entram no calendário | |
| Sem prazo vai para criação | Usa created_at como fallback | ✓ |

**Decisão do usuário:** deadline ?? created_at — todas as auditorias aparecem no calendário.

---

## Claude's Discretion

- Design visual dos indicadores por dia (badges, dots, chips) — Claude escolhe o mais legível
- Implementação do calendário: widget customizado vs pacote (`table_calendar`) — Claude avalia
- Comportamento ao tocar em dia sem auditorias — Claude decide

## Deferred Ideas

- Relatórios (REP-01/02/03/04) — removidos do roadmap atual; novo phase se necessário no futuro
- Criar auditoria a partir do calendário — fora do escopo desta fase
- Indicador de conformidade no dia do calendário — fora do escopo
- Calendário em tempo real via Supabase Realtime — fora do escopo
