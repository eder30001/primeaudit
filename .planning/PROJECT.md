# QAudit

## What This Is

App Flutter para realização de auditorias industriais e checklists em campo. Auditores executam checklists configuráveis por template, registrando respostas por item com cálculo automático de conformidade ponderada. O backend é Supabase (auth, banco, RLS) e o app suporta múltiplas empresas com RBAC por perfil.

Funcionalidades ativas: dashboard com KPIs reais e calendário, ações corretivas com fluxo CAPA completo, upload de fotos por pergunta, módulo de checklist independente (templates, execução, fotos).

## Current Milestone: v1.3 Notificações

**Goal:** Auditores recebem notificações push no dispositivo quando ações corretivas são atribuídas/atualizadas e quando auditorias são criadas com eles como responsável.

**Target features:**
- FCM (Firebase Cloud Messaging) integrado ao app Android
- Registro e armazenamento de device token por usuário autenticado
- Push ao atribuir ação corretiva a um usuário
- Push ao alterar status de ação que me foi atribuída ou que criei
- Push ao criar auditoria com meu perfil como responsável
- Backend: Supabase Edge Functions ou Database Webhooks para disparar FCM

## Previous Milestone — v1.2 Shipped

**Shipped:** 2026-05-13
**Codebase:** ~17.000 LOC Dart, arquitetura 3 camadas (screens → services → models)
**Stack:** Flutter 3.38.4, Dart 3.11.4, Supabase (auth + db + storage + RLS)

**Módulos ativos:**
- Auditorias: criação (4 etapas), execução, encerramento, conformidade ponderada
- Ações corretivas: fluxo CAPA completo (6 estados), fotos, RBAC por role
- Dashboard: KPIs reais, calendário mensal de auditorias
- Checklists: templates (CRUD + clonagem + 10 seeds), execução completa com auto-save, fotos por item

## Core Value

Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## Requirements

### Validated

- ✓ Autenticação email/senha com perfis RBAC (superuser, admin, auditor) — v1.0
- ✓ Scoping por empresa via CompanyContextService — v1.0
- ✓ Templates de auditoria com itens configuráveis — v1.0
- ✓ Fluxo completo de auditorias: criação, execução, encerramento/cancelamento — v1.0
- ✓ Cálculo de conformidade ponderado por peso e tipo de resposta — v1.0
- ✓ Seleção de perímetro hierárquico em cascata — v1.0
- ✓ Tema claro/escuro via ValueNotifier — v1.0
- ✓ Migrations SQL idempotentes para Supabase — v1.0
- ✓ Dashboard com KPIs reais (total, pendentes, atrasadas, ações abertas) — v1.1
- ✓ Calendário mensal de auditorias no dashboard — v1.1
- ✓ Ações corretivas com fluxo CAPA completo (6 estados, RBAC) — v1.1
- ✓ Upload e visualização de fotos por pergunta (Supabase Storage) — v1.1
- ✓ Templates de checklist com CRUD, clonagem e 10 seeds — v1.2
- ✓ Execução de checklist com todos os tipos de resposta e auto-save — v1.2
- ✓ Fotos por item durante execução de checklist — v1.2
- ✓ Entrada "Checklist" no drawer de navegação — v1.2

### Active (v1.3)

- [ ] Usuário recebe push quando ação corretiva é atribuída a ele — NOTIF-01
- [ ] Usuário recebe push quando status de ação atribuída ou criada por ele é alterado — NOTIF-02
- [ ] Usuário recebe push quando auditoria é criada com ele como responsável — NOTIF-03
- [ ] Device token do dispositivo é registrado e atualizado no backend por sessão — NOTIF-04

### Out of Scope

- Modo offline completo com sync posterior — requer sqflite + refactor de estado (Phase 999.2 no backlog)
- Exportação em PDF — v2, após histórico e conformidade estarem estáveis
- Relatórios consolidados multi-empresa — admin feature de v2
- FAB expandível + drawer simplificado — cancelado em v1.1
- Notificações por prazo vencendo (cron) — v2+ (requer pg_cron ou Edge Function agendada)
- Assinatura digital ao finalizar checklist (EXEC-06) — v1.4+
- Histórico de checklists com filtros e conformidade (HIST-01/02/03) — v1.4+
- Ações corretivas vinculadas a itens NOK do checklist (CAPA-CK-01) — v1.4+
- UI in-app de notificações (badge, tela de histórico) — v1.4+ se necessário
- iOS push notifications (APN) — Android first em v1.3

## Context

- App em uso em campo por auditores; módulo de checklist adicionado em v1.2
- Codebase: ~17.000 LOC Dart, arquitetura 3 camadas estável
- Stack: Flutter 3.38.4, Dart 3.11.4, Supabase (auth + db + storage + RLS)
- Gerenciamento de estado: setState local + ValueNotifier global — sem BLoC/Riverpod
- Suporte a múltiplas empresas via CompanyContextService singleton
- Offline mode: explorado e revertido em v1.2 — requer abordagem mais estruturada (999.2)
- Navegação: drawer com Dashboard, Auditorias, Checklists, Ações Corretivas, Templates*, Administração*, Perfil, Configurações

## Constraints

- **Stack**: Flutter + Dart + Supabase — sem trocar de stack
- **Estado**: Sem introduzir BLoC/Riverpod/Provider — refactor de estado é milestone separada
- **DB**: Migrações devem seguir padrão idempotente YYYYMMDD_description.sql
- **Compatibilidade**: Não quebrar fluxos existentes (auditorias, checklists, ações corretivas)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Corrigir estrutura antes de novas features (v1.0) | Base sólida reduz risco técnico em produção | ✓ Bom |
| Manter setState como gerenciamento de estado | Refactor é milestone separada | ✓ Bom — mantido em v1.2 |
| RLS como camada de segurança principal | anon key é public by design no Supabase | ✓ Bom |
| Upload de imagens independente de _saveAnswer | Falha não bloqueia finalização — core value | ✓ Bom |
| REP-01–04 substituídos por Calendar Dashboard | Usuário priorizou calendário sobre relatórios separados | ✓ Bom |
| Phase 11 (Notifications) adiada | FCM + Edge Functions têm alta complexidade | — Pendente v1.3 |
| Módulo Checklist independente do Auditoria | Zero acoplamento — módulos evoluem separados | ✓ Bom |
| Seeds com UUIDs hardcoded + ON CONFLICT DO NOTHING | Idempotência garantida em re-runs da migration | ✓ Bom |
| RLS Pattern 3: subquery via FK para itens filhos | Sem created_by direto na tabela filha — clean | ✓ Bom |
| Offline mode via SharedPreferences revertido | Abordagem ad-hoc não funcionou; requer sqflite + Riverpod | ⚠ Revisitar em v2 |
| Phases 16/17 canceladas | Dados históricos insuficientes em produção; escopo melhor em v1.3 | — Aceito |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---

*Last updated: 2026-05-13 — v1.3 Notificações milestone iniciado*
