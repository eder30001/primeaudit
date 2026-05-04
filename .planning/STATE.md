---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Checklist
status: executing
stopped_at: ""
last_updated: "2026-05-04T00:00:00Z"
last_activity: 2026-05-04
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 4
  completed_plans: 0
  percent: 0
phases:
  - id: 13
    name: DB Foundation + Template Management
    status: in_progress
  - id: 14
    name: Checklist Execution Engine
    status: not_started
  - id: 15
    name: Photos per Item
    status: not_started
  - id: 16
    name: Digital Signature
    status: not_started
  - id: 17
    name: History + Conformity Indicators
    status: not_started
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.
**Current focus:** Módulo de Checklist independente (v1.2)

## Current Position

Phase: 13 — DB Foundation + Template Management
Plan: 13-02 (Wave 2 of 4) — CONCLUÍDO
Plan: 13-03 (Wave 3 of 4) — próximo (screens: ChecklistTemplatesScreen + ChecklistTemplateFormScreen)
Status: Executing — Plan 13-02 completo; pronto para Plan 13-03
Last activity: 2026-05-04 — Plan 13-02 concluído (commits f2877b0, 0ae316c); model + service + tests

Progress: [----------] 10% (0/5 phases complete; Phase 13 Plans 1-2/4 concluídos)

## Accumulated Context

### Decisions (v1.0 carryover)

- Manter setState como gerenciamento de estado — refactor é milestone separada
- RLS como camada de segurança principal — anon key é public by design no Supabase
- Migrations SQL seguem padrão idempotente YYYYMMDD_description.sql
- Arquitetura 3 camadas: screens → services → models (sem DI, sem BLoC/Riverpod)

### Decisions (v1.1)

- canTransitionTo usa createdBy (criador) como avaliador, não "qualquer auditor"
- NotificationService deve ser singleton (padrão CompanyContextService) — para Phase 11
- Upload de imagens é fluxo independente de _saveAnswer — falha não bloqueia finalização (core value)
- fl_chart instalado em Phase 7 — não adicionar novamente
- Escopo de Relatórios substituído por Calendário de Auditorias no Dashboard

### Decisions (v1.2)

- Módulo Checklist é independente do módulo de Auditoria — zero alterações em AuditTemplateService, AuditAnswerService, ImageService, AuditExecutionScreen
- Seeds de checklist_templates usam UUIDs hardcoded (a1b2c3d4-0001-..., b2c3d4e5-0002-...) — imutáveis após migration aplicada
- template_id em checklist_template_items tem DEFAULT gen_random_uuid() apenas para satisfazer NOT NULL no ADD COLUMN IF NOT EXISTS — scaffold de idempotência, não regra de negócio
- RLS items: subquery via FK para derivar ownership (sem created_by direto na tabela filha) — Pattern 3 estabelecido
- checklist-images usa bucket separado de audit-images — evita acoplamento FK
- Seed templates com UUIDs hardcoded + ON CONFLICT DO NOTHING — idempotência da migration
- Clone sequencial: criar seções antes de itens para evitar FK órfão (Pitfall #3)
- Upload de fotos independente de auto-save — falha não bloqueia execução (core value)
- REP-01/02 (PDF export) movidos para v2 — complexidade de compute isolate + FileProvider Android
- Tipos number e date excluídos do denominador do cálculo de conformidade
- Package signature ^9.0.0 para assinatura digital; toPngBytes() → Supabase Storage
- checklist_template.dart sem imports (pure Dart) — sem Color/IconData em Phase 13
- getByCategory usa apenas .eq('category') — RLS já filtra seeds + own via policy
- replaceItems = delete-all + re-insert com order_index 0..n-1 via asMap().entries (Pitfall 5 resolvido)

### Blockers/Concerns

- NOTIF-03 (FCM push) tem alta complexidade de setup (firebase_messaging, google-services.json, APNs) — avaliar no planejamento da próxima milestone se NOTIF-01/02 podem ser entregues sem FCM primeiro
- Ordering de perguntas (order_index) não corrigida — TMPL-01 cancelada; pode ser retomada se ordenação incorreta causar problemas em campo
- Verificar versão atual de signature após flutter pub get (9.0.0 MEDIUM confidence)
- Confirmar se image_picker (Phase 9) já declarou FileProvider no AndroidManifest.xml antes de Phase 15
