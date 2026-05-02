# Milestones — PrimeAudit

---

## v1.1 — Features & UX

**Shipped:** 2026-05-02
**Phases:** 7–10 (4 delivered) | **Plans:** 12
**Timeline:** 2026-04-23 → 2026-05-02 (9 days)

### Delivered

1. Dashboard com KPIs reais, pull-to-refresh e gráfico de conformidade por template (fl_chart)
2. Fluxo completo de ações corretivas CAPA com 6 estados, RBAC por role, badge de contagem
3. Upload e visualização de fotos por pergunta durante execução (Supabase Storage, múltiplas imagens)
4. Calendário mensal de auditorias no dashboard com indicadores por dia e navegação filtrada por data

### Cancelled / Deferred

- Phase 6 (Templates): drag & drop e ordenação de perguntas — cancelado
- Phase 11 (Notifications): in-app + email + FCM — adiado para v1.2
- Phase 12 (Navigation Refactor): FAB expandível + drawer simplificado — cancelado

### Known Deferred Items at Close: 2

- Phase 11: Notifications (NOTIF-01/02/03) — deferred to future milestone
- Phase 999.1: Responsável externo por email — backlog

Archive: [.planning/milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

---

## v1.0 — Foundation

**Shipped:** 2026-04-17
**Phases:** 1–4 (4 delivered) | Phase 5 deferred to v2

### Delivered

1. Correção de save silencioso em audit_execution_screen — core value protegido
2. RLS policies para todas as tabelas críticas + bloqueio server-side de operações sensíveis
3. Suite de testes unitários para conformidade, roles, modelos e árvore de perímetro
4. Batch upsert em reorderItems (substituição de loop sequencial)
