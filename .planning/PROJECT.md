# PrimeAudit

## What This Is

App Flutter para realização de auditorias industriais em campo. Auditores executam checklists configuráveis por template, registrando respostas por item com cálculo automático de conformidade ponderada. O backend é Supabase (auth, banco, RLS) e o app suporta múltiplas empresas com RBAC por perfil.

Funcionalidades ativas: dashboard com KPIs reais, ações corretivas com fluxo CAPA completo, upload de fotos por pergunta, e calendário de auditorias no dashboard.

## Core Value

Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## Requirements

### Validated

- ✓ Autenticação email/senha com perfis RBAC (superuser, admin, auditor, viewer) — v1.0
- ✓ Scoping por empresa via CompanyContextService — v1.0
- ✓ Templates de auditoria com itens configuráveis (tipos: ok_nok, yes_no, scale_1_5, percentage, text, selection) — v1.0
- ✓ Fluxo completo de auditorias: criação (4 etapas), execução, encerramento/cancelamento — v1.0
- ✓ Cálculo de conformidade ponderado por peso e tipo de resposta — v1.0
- ✓ Seleção de perímetro hierárquico em cascata — v1.0
- ✓ Tema claro/escuro via ValueNotifier — v1.0
- ✓ Migrations SQL idempotentes para Supabase — v1.0
- ✓ Dashboard com KPIs reais: total, pendentes, atrasadas, ações abertas (scoped por empresa, RBAC) — v1.1 Phase 7
- ✓ Pull-to-refresh no dashboard — v1.1 Phase 7
- ✓ Gráfico de conformidade média por template (fl_chart) — v1.1 Phase 7
- ✓ Ações corretivas com fluxo CAPA completo (6 estados, RBAC por role) — v1.1 Phase 8
- ✓ Criação de ação vinculada a pergunta durante execução — v1.1 Phase 8
- ✓ Badge de ações abertas na navegação — v1.1 Phase 8
- ✓ Upload e visualização de fotos por pergunta (Supabase Storage) — v1.1 Phase 9
- ✓ Múltiplas imagens por pergunta com miniaturas inline — v1.1 Phase 9
- ✓ Calendário mensal de auditorias no dashboard com indicadores por dia — v1.1 Phase 10
- ✓ Navegação AuditsScreen filtrada por data a partir do calendário — v1.1 Phase 10

### Active

- [ ] Notificações in-app e email automático para ações atribuídas (NOTIF-01/02/03) — deferred from v1.1
- [ ] Responsável externo por email nas ações corretivas (999.1) — backlog

### Out of Scope

- Modo offline completo com sync posterior — complexidade alta, milestone futura
- Exportação em PDF/Excel — v2 após relatórios básicos estarem funcionando
- Relatórios consolidados multi-empresa — admin feature de v2
- FAB expandível + drawer simplificado (NAV-01/02) — cancelado em v1.1
- Ordenação automática e drag & drop de perguntas no template (TMPL-01/02) — cancelado em v1.1
- Notificações por prazo vencendo — requer cron job, v2+

## Context

- App com funcionalidades core entregues em v1.1; pronto para uso em campo por auditores
- Codebase: ~13.000 LOC Dart, arquitetura 3 camadas (screens → services → models)
- Stack: Flutter 3.38.4, Dart 3.11.4, Supabase (auth + db + storage + RLS)
- Gerenciamento de estado: setState local + ValueNotifier global (tema) — sem BLoC/Riverpod
- Suporte a múltiplas empresas via CompanyContextService (singleton com SharedPreferences)
- Test suite: testes unitários para serviços core (DashboardService, conformidade, roles, modelos)
- Navegação atual: drawer com Dashboard, Administração*, Templates*, Auditorias, Ações Corretivas, Perfil, Configurações, Sair
- Próxima milestone: Notificações in-app + email automático

## Constraints

- **Stack**: Flutter + Dart + Supabase — sem trocar de stack
- **Estado**: Sem introduzir BLoC/Riverpod/Provider — refactor de estado é milestone separada
- **DB**: Migrações devem seguir padrão idempotente já estabelecido
- **Compatibilidade**: Não quebrar fluxos existentes (criação/execução/encerramento de auditorias)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Corrigir estrutura antes de novas features (v1.0) | App em desenvolvimento; risco técnico alto se problemas fossem para produção | ✓ Bom — base sólida para v1.1 |
| Manter setState como gerenciamento de estado | Refactor completo é milestone separada, não misturar com features | ✓ Bom — mantido em v1.1 |
| RLS como camada de segurança principal | anon key é public by design no Supabase; segurança depende de RLS correto | ✓ Bom — padrão mantido |
| Phase 7 com fallback 0 para corrective_actions | Phase 8 entregou a migration; Phase 7 executada em paralelo com valor zero | ✓ Bom — sem bloqueio |
| canTransitionTo usa createdBy como avaliador | Responsável não pode avaliar a própria ação — createdBy (auditor) avalia | ✓ Bom — RBAC correto |
| NotificationService como singleton | Manter unreadCount vivo entre navegações sem Realtime | — Pending (v1.1 deferred) |
| Upload de imagens independente de _saveAnswer | Falha de upload não bloqueia finalização de auditoria — core value mantido | ✓ Bom |
| REP-01–04 substituídos por Calendar Dashboard | Usuário priorizou calendário no dashboard sobre tela de relatórios separada | ✓ Bom — menos complexidade |
| Phase 6/12 canceladas | Templates drag & drop e FAB de navegação removidos do escopo | — Aceito como trade-off |
| Phase 11 adiada | FCM + Edge Functions têm alta complexidade de setup — milestone dedicada | — Pendente |

---

*Last updated: 2026-05-02 — v1.1 Features & UX milestone complete*
