# Milestones — PrimeAudit

---

## v1.2 — Checklist

**Shipped:** 2026-05-13
**Phases:** 13–15 (3 delivered, 2 cancelled) | **Plans:** 12
**Timeline:** 2026-05-03 → 2026-05-13 (10 dias) | **Commits:** 79

### Delivered

1. Módulo de templates de checklist: CRUD, clonagem, 10 seeds industriais/transportadora, RLS completo
2. Engine de execução com todos os tipos de resposta (Sim/Não, texto, número, data, múltipla escolha) e auto-save silencioso
3. Fotos por item durante execução via câmera ou galeria (bucket checklist-images, RLS Pattern 3)
4. Bug fixes pós-migração de banco: templates, upload de imagens para superuser/dev, corrective_action_id, overflow de UI

### Cancelled / Deferred

- Phase 16 (Assinatura digital): complexidade de canvas + Storage PNG — deferred to v1.3
- Phase 17 (Histórico + conformidade): requer dados acumulados em produção — deferred to v1.3

### Known Gaps at Close: 4

- EXEC-06: Assinatura digital → v1.3
- HIST-01/02/03: Histórico de checklists → v1.3

Archive: [.planning/milestones/v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md)

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
