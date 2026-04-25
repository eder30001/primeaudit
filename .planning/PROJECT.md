# PrimeAudit

## Current Milestone: v1.1 Features & UX

**Goal:** Adicionar as funcionalidades core que tornam o app utilizável em produção — dashboard, relatórios, ações corretivas e melhorias de UX.

**Target features:**
- Dashboard com indicadores de auditorias (US-01)
- Menu flutuante FAB para navegação (US-02)
- Tela de relatórios com filtros (US-03)
- Tela de ações corretivas (US-04)
- Upload de imagens nas perguntas (US-05)
- Criação de ações diretamente nas auditorias (US-06)
- Notificações e email automático (US-07)
- Ordenação automática de perguntas no template (US-08)
- Reordenação manual drag & drop ou botões (US-09)

---

## What This Is

App Flutter para realização de auditorias industriais em campo. Auditores executam checklists configuráveis por template, registrando respostas por item com cálculo automático de conformidade ponderada. O backend é Supabase (auth, banco, RLS) e o app suporta múltiplas empresas com RBAC por perfil.

## Core Value

Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## Requirements

### Validated

- ✓ Autenticação email/senha com perfis RBAC (superuser, admin, auditor, viewer) — existente
- ✓ Scoping por empresa via CompanyContextService — existente
- ✓ Templates de auditoria com itens configuráveis (tipos: ok_nok, yes_no, scale_1_5, percentage, text, selection) — existente
- ✓ Fluxo completo de auditorias: criação (4 etapas), execução, encerramento/cancelamento — existente
- ✓ Cálculo de conformidade ponderado por peso e tipo de resposta — existente
- ✓ Seleção de perímetro hierárquico em cascata — existente
- ✓ Tema claro/escuro via ValueNotifier — existente
- ✓ Migrations SQL idempotentes para Supabase — existente

### Active

- [x] Dashboard com indicadores: total de auditorias, pendentes, ações em aberto — Validated in Phase 7: real KPIs, pull-to-refresh, fl_chart conformity bar chart, role-scoped (auditor vê apenas suas auditorias)
- [ ] Menu flutuante FAB com navegação animada nas telas principais
- [ ] Tela de relatórios com filtros por data e template, exibição em lista/gráfico
- [ ] Tela de ações corretivas com status (aberta, em andamento, concluída) e filtros
- [ ] Upload e visualização de imagens por pergunta nas auditorias
- [ ] Criação de ações corretivas vinculadas a perguntas, com responsável e prazo
- [ ] Notificações in-app e email automático para ações atribuídas
- [ ] Ordenação automática e reordenação manual (drag & drop ou botões) de perguntas

### Out of Scope

- Modo offline completo com sync posterior — complexidade alta, milestone futura
- Exportação em PDF/Excel — v2 após relatórios básicos estarem funcionando
- Relatórios consolidados multi-empresa — admin feature de v2

## Context

- App em desenvolvimento ativo, sem usuários reais ainda
- Codebase mapeado em 2026-04-16: arquitetura 3 camadas (screens → services → models), sem DI, sem BLoC/Riverpod
- Gerenciamento de estado: setState local + um ValueNotifier global (tema)
- Suporte a múltiplas empresas via CompanyContextService (singleton com SharedPreferences)
- Test suite: apenas scaffold Flutter padrão (contador inexistente) — zero cobertura real
- O risco mais crítico identificado: save silencioso de respostas em `audit_execution_screen.dart:228`

## Constraints

- **Stack**: Flutter + Dart + Supabase — sem trocar de stack nesta milestone
- **Estado**: Sem introduzir BLoC/Riverpod/Provider nesta milestone — refactor de estado é trabalho futuro separado
- **DB**: Migrações devem seguir padrão idempotente já estabelecido
- **Compatibilidade**: Não quebrar fluxos existentes (criação/execução/encerramento de auditorias)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Corrigir estrutura antes de novas features | App está em desenvolvimento; risco técnico alto se problemas forem para produção | — Pending |
| Manter setState como gerenciamento de estado | Refactor completo é milestone separada, não misturar com correção de bugs | — Pending |
| RLS como camada de segurança principal | anon key é public by design no Supabase; segurança depende de RLS correto | — Pending |

## Evolution

Este documento evolui a cada transição de fase e milestone.

**Após cada fase** (via `/gsd-transition`):
1. Requirements invalidados? → Mover para Out of Scope com motivo
2. Requirements validados? → Mover para Validated com referência da fase
3. Novos requirements? → Adicionar em Active
4. Decisões a registrar? → Adicionar em Key Decisions
5. "What This Is" ainda preciso? → Atualizar se driftar

**Após cada milestone** (via `/gsd-complete-milestone`):
1. Revisão completa de todas as seções
2. Core Value check — ainda é a prioridade certa?
3. Auditar Out of Scope — motivos ainda válidos?
4. Atualizar Context com estado atual

---
*Last updated: 2026-04-25 — Phase 07 complete (DASH-01 real KPIs scoped por empresa, DASH-02 pull-to-refresh, DASH-03 fl_chart conformity bar chart)*
