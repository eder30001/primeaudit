# Requirements: PrimeAudit — Features & UX (v1.1)

**Defined:** 2026-04-18
**Milestone:** v1.1
**Core Value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

---

## v1.1 Requirements

### Dashboard (DASH)

- [ ] **DASH-01**: Usuário vê cards com total de auditorias, pendentes, atrasadas e ações em aberto (scoped por empresa)
- [ ] **DASH-02**: Usuário pode atualizar o dashboard via pull-to-refresh
- [ ] **DASH-03**: Usuário vê gráfico de conformidade média por template de auditoria

### Ações Corretivas (ACT)

- [ ] **ACT-01**: Usuário vê lista de ações corretivas com status e filtros por responsável e status
- [ ] **ACT-02**: Auditor pode criar ação vinculada a uma pergunta durante a execução, definindo responsável e prazo
- [ ] **ACT-03**: Status segue fluxo CAPA com 6 estados (aberta → em_andamento → em_avaliacao → aprovada/rejeitada/cancelada); Admin altera qualquer status; Responsável pode mover para em_andamento e em_avaliacao; Auditor pode mover para aprovada e rejeitada
- [ ] **ACT-04**: Badge com contagem de ações abertas visível na navegação principal

### Imagens nas Perguntas (IMG)

- [ ] **IMG-01**: Usuário pode anexar foto (câmera ou galeria) por pergunta durante a execução da auditoria
- [ ] **IMG-02**: Miniaturas das imagens anexadas são exibidas inline na card da pergunta
- [ ] **IMG-03**: Múltiplas imagens por pergunta são suportadas

### Relatórios (REP)

- [ ] **REP-01**: Usuário pode filtrar relatórios por intervalo de datas
- [ ] **REP-02**: Usuário pode filtrar relatórios por template de auditoria
- [ ] **REP-03**: Relatório exibe lista de auditorias concluídas com % de conformidade calculada
- [ ] **REP-04**: Relatório exibe gráfico de conformidade média por template (fl_chart)

### Notificações (NOTIF)

- [ ] **NOTIF-01**: Usuário vê central de notificações in-app com badge de não lidas no AppBar
- [ ] **NOTIF-02**: Responsável recebe email automático quando ação corretiva é atribuída a ele (Supabase Edge Function)
- [ ] **NOTIF-03**: Usuário recebe push notification via FCM quando app está em background/fechado

### Navegação (NAV)

- [ ] **NAV-01**: FAB expandível nas telas principais dá acesso a Dashboard, Auditorias, Ações Corretivas, Relatórios e Notificações
- [ ] **NAV-02**: Menu lateral (drawer) exibe apenas Perfil e Configurações — demais itens removidos

### Templates (TMPL)

- [ ] **TMPL-01**: Perguntas são exibidas na ordem correta (order_index) na tela de execução da auditoria
- [ ] **TMPL-02**: Usuário pode reordenar perguntas no template builder via drag & drop com persistência no banco

---

## Out of Scope (v1.1)

| Feature | Reason |
|---------|--------|
| Exportação PDF/Excel | Nova funcionalidade complexa — v2 após relatórios básicos funcionando |
| Relatórios consolidados multi-empresa | Admin feature de v2 |
| Notificações por prazo vencendo | Requer cron job — v2 |
| Modo offline completo com sync | Alta complexidade — milestone futura |
| Edição de ações por qualquer auditor | Apenas responsável, auditor verificador e admin |

---

## v1.0 Requirements (Completed)

### Integridade de Dados (DINT)
- [x] **DINT-01**: Auditor vê mensagem de erro quando save de resposta falha por rede ou timeout
- [x] **DINT-02**: Item com save pendente exibe indicador visual distinto (spinner/ícone)
- [x] **DINT-03**: Auditor pode re-tentar manualmente o save de um item com falha

### Segurança (SEC)
- [x] **SEC-01**: RLS policies documentadas para todas as tabelas críticas
- [x] **SEC-02**: Operações sensíveis (updateRole) bloqueadas por RLS no servidor
- [x] **SEC-03**: Usuário com active=false não acessa dados mesmo com JWT válido
- [x] **SEC-04**: CNPJ validado com dígitos verificadores antes de chegar ao banco

### Qualidade (QUAL)
- [x] **QUAL-01**: calculateConformity tem testes para todos os 6 tipos de resposta
- [x] **QUAL-02**: AppRole helpers testados para todos os 5 roles
- [x] **QUAL-03**: fromMap() dos 7 models testados com campos críticos
- [x] **QUAL-04**: Perimeter.buildTree() testado com hierarquias de 0-3 níveis

### Performance (PERF)
- [x] **PERF-01**: reorderItems usa batch upsert em vez de loop sequencial com await

### Configuração (CONF)
- [ ] **CONF-01**: Configurações críticas lidas do servidor (Supabase), não apenas do dispositivo local *(deferido para v2)*

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DASH-01 | Phase 7 | Pending |
| DASH-02 | Phase 7 | Pending |
| DASH-03 | Phase 7 | Pending |
| ACT-01 | Phase 8 | Pending |
| ACT-02 | Phase 8 | Pending |
| ACT-03 | Phase 8 | Pending |
| ACT-04 | Phase 8 | Pending |
| IMG-01 | Phase 9 | Pending |
| IMG-02 | Phase 9 | Pending |
| IMG-03 | Phase 9 | Pending |
| REP-01 | Phase 10 | Pending |
| REP-02 | Phase 10 | Pending |
| REP-03 | Phase 10 | Pending |
| REP-04 | Phase 10 | Pending |
| NOTIF-01 | Phase 11 | Pending |
| NOTIF-02 | Phase 11 | Pending |
| NOTIF-03 | Phase 11 | Pending |
| NAV-01 | Phase 12 | Pending |
| NAV-02 | Phase 12 | Pending |
| TMPL-01 | Phase 6 | Pending |
| TMPL-02 | Phase 6 | Pending |

---

*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 — milestone v1.1 started*
