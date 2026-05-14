# Requirements: QAudit

**Defined:** 2026-05-13
**Core Value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## v1.3 Requirements

### Notificações (NOTIF)

- [ ] **NOTIF-01**: Usuário recebe push notification quando uma ação corretiva é atribuída a ele
- [ ] **NOTIF-02**: Usuário recebe push notification quando o status de uma ação atribuída a ele ou criada por ele é alterado
- [ ] **NOTIF-03**: Usuário recebe push notification quando uma auditoria é criada com ele como responsável
- [ ] **NOTIF-04**: App solicita permissão de notificação e registra device token no backend ao iniciar sessão autenticada
- [ ] **NOTIF-05**: Push notification exibe título e corpo descritivos com contexto da ação (ex: "Ação #42 atribuída a você")

### Infraestrutura (INFRA)

- [ ] **INFRA-01**: Tabela `device_tokens` armazena token FCM por usuário (sobrescreve token ao renovar, mantém um por usuário)
- [ ] **INFRA-02**: Supabase Edge Function recebe evento de banco e envia push via FCM HTTP API v1
- [ ] **INFRA-03**: Firebase Cloud Messaging configurado no projeto Android (google-services.json + firebase_messaging package)

## v1.4 Requirements (Deferred)

### Histórico de Checklists

- **HIST-01**: Usuário pode visualizar histórico de checklists com filtros (data, tipo, responsável, local)
- **HIST-02**: Usuário pode abrir checklist concluído em modo leitura com todas as respostas
- **HIST-03**: Histórico exibe indicadores de conformidade (% de itens OK) por checklist

### Checklist — Execução

- **EXEC-06**: Auditor pode assinar digitalmente ao finalizar checklist

### CAPA Checklist

- **CAPA-CK-01**: Auditor pode criar ação corretiva vinculada a item NOK durante execução de checklist

### Notificações (futuro)

- **NOTIF-06**: Usuário recebe push notification quando ação corretiva sob sua responsabilidade está próxima do prazo (cron diário)
- **NOTIF-07**: App exibe badge com contagem de notificações não lidas
- **NOTIF-08**: Usuário acessa histórico de notificações dentro do app

## Out of Scope

| Feature | Motivo |
|---------|--------|
| Notificação por prazo vencendo | Requer pg_cron ou Edge Function agendada — v2+ |
| UI in-app (badge, tela de histórico) | Fora do foco de v1.3 — v1.4+ se necessário |
| iOS push notifications (APN) | Android first em v1.3 |
| Múltiplos device tokens por usuário | Sobrescreve token ao renovar — simplifica v1.3 |
| Modo offline completo com sync | Requer sqflite + refactor de estado (Phase 999.2 backlog) |
| Exportação em PDF | v2, após histórico e conformidade estarem estáveis |
| Relatórios consolidados multi-empresa | Admin feature de v2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-03 | Phase 18 | Pending |
| INFRA-01 | Phase 18 | Pending |
| NOTIF-04 | Phase 19 | Pending |
| NOTIF-01 | Phase 20 | Pending |
| NOTIF-02 | Phase 20 | Pending |
| NOTIF-03 | Phase 20 | Pending |
| NOTIF-05 | Phase 20 | Pending |
| INFRA-02 | Phase 20 | Pending |

**Coverage:**
- v1.3 requirements: 8 total
- Mapped to phases: 8/8
- Unmapped: 0

---
*Requirements defined: 2026-05-13*
*Last updated: 2026-05-13 — traceability complete, roadmap phases 18–20 assigned*
