---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Onboarding, Billing & Notificações
status: active
stopped_at: ""
last_updated: "2026-05-13T21:00:00Z"
last_activity: 2026-05-15
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-13)

**Core value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.
**Current focus:** v1.3 Onboarding, Billing & Notificações — Phase 21: Company Self-Registration

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260515-qzt | Criar tela hub "Modelos" no drawer | 2026-05-15 | cebc460 | [260515-qzt-criar-tela-hub-modelos](./quick/260515-qzt-criar-tela-hub-modelos/) |

## Current Position

Phase: 21 — Company Self-Registration
Plan: 3 plans (21-01, 21-02, 21-03) | 2 waves
Status: Ready to execute
Progress: ░░░░░░░░░░ 0% (0 of 6 phases complete)

Roadmap: 6 phases (18–23) | Firebase phases (18–20) postponed | Onboarding + Billing (21–23) priority

## Deferred Items (acknowledged at v1.2 close)

| Requirement | Description | Target |
|-------------|-------------|--------|
| EXEC-06 | Assinatura digital ao finalizar checklist | v1.4+ |
| HIST-01 | Histórico de checklists com filtros | v1.4+ |
| HIST-02 | Visualização de checklist concluído em modo leitura | v1.4+ |
| HIST-03 | Indicadores de conformidade no histórico | v1.4+ |

## Accumulated Context

### Decisions carryover

- Manter setState — refactor de estado é milestone separada
- RLS como camada de segurança principal
- Migrations SQL seguem padrão idempotente YYYYMMDD_description.sql
- Arquitetura 3 camadas: screens → services → models
- Módulo Checklist independente do módulo de Auditoria
- Offline mode revertido — requer sqflite + Riverpod (Phase 999.2 backlog)
- Android first para FCM — iOS (APN) é out of scope em v1.3
- Sem UI in-app de notificações (sem badge, sem tela de histórico) — v1.4+ se necessário
- device_tokens: um token por usuário (sobrescreve ao renovar) — simplifica v1.3

### v1.3 Phase Map

| Phase | Name | Requirements | Priority |
|-------|------|--------------|----------|
| 18 | Firebase Infrastructure | INFRA-03, INFRA-01 | Postponed |
| 19 | Token Registration | NOTIF-04 | Postponed |
| 20 | Backend Triggers + Push Dispatch | NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-05, INFRA-02 | Postponed |
| 21 | Company Self-Registration | ONBOARD-01 | **Next** |
| 22 | Asaas Billing Integration | BILLING-01, BILLING-02, BILLING-03 | After 21 |
| 23 | Invite Users by Email | ONBOARD-02 | After 21 |

### Decisions (v1.3 additions)

- Asaas escolhido como gateway de pagamento (PIX/boleto/cartão, API BR, NF automática)
- Trial de 30 dias sem cartão → cobrança por email ao vencer
- Supabase Edge Functions para chamadas que requerem service_role (invite + Asaas)
- pg_cron para jobs diários de verificação de licença
- Superuser/dev isentos de controle de licença
