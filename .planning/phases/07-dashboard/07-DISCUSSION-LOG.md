# Phase 7: Dashboard - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-23
**Phase:** 07-dashboard
**Areas discussed:** KPIs — definição dos cards

---

## KPIs — definição dos cards

### Pergunta 1: O que 'pendentes' significa?

| Option | Selected |
|--------|----------|
| Apenas em_andamento | ✓ |
| Em andamento + Rascunhos | |
| Auditorias próximas do prazo | |

**Notes:** Rascunhos são drafts, não trabalho pendente.

---

### Pergunta 2: O 'total de auditorias' inclui quais status?

| Option | Selected |
|--------|----------|
| Todos os status | |
| Todos exceto canceladas | ✓ |
| Apenas do período atual | |

**Notes:** Usuário especificou em texto livre: "todas exceto canceladas".

---

### Pergunta 3: Ações abertas antes da Phase 8

| Option | Selected |
|--------|----------|
| Mostrar 0 | ✓ |
| Ocultar o card | |
| Mostrar '—' | |

---

### Pergunta 4: KPI cards variam por role?

| Option | Selected |
|--------|----------|
| Mesmos para todos | |
| Diferentes por role | ✓ |

---

### Pergunta 5: O que muda por role?

| Option | Selected |
|--------|----------|
| Auditor vê só as suas | ✓ |
| Admin/Adm vê todas da empresa | ✓ |
| Superuser/Dev vê card extra | ✓ |

---

### Pergunta 6: Card extra Superuser/Dev mostra o quê?

| Option | Selected |
|--------|----------|
| Número de empresas | |
| Número de usuários ativos | |
| Você decide | ✓ |

**Notes:** Claude usará "total de empresas" — já é o placeholder atual no código.

---

## Claude's Discretion

- Card extra Superuser/Dev: total de empresas cadastradas
- Estratégia de dados: Claude decide (fetch único vs COUNT queries)
- Gráfico DASH-03: tipo, período e layout — Claude decide
- Posicionamento do gráfico: abaixo dos 4 cards, substituindo "Atividade recente"

## Deferred Ideas

- Gráfico interativo com filtro de período selecionável
- Seção "Atividade recente" com lista das últimas N auditorias
- KPIs em tempo real via Supabase Realtime
