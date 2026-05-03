# Requirements: PrimeAudit

**Defined:** 2026-05-02
**Core Value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## v1.2 Requirements

### Template Management

- [ ] **TMPLCK-01**: Usuário vê templates listados por categoria (Industrial / Transportadora / Meus checklists)
- [ ] **TMPLCK-02**: Usuário cria template customizado com nome, categoria, descrição e lista de itens
- [ ] **TMPLCK-03**: Usuário edita template customizado existente (itens, ordem, metadados)
- [ ] **TMPLCK-04**: Usuário exclui template customizado que criou
- [ ] **TMPLCK-05**: Usuário clona qualquer template (seed ou próprio) como base para novo
- [ ] **TMPLCK-06**: 10 templates seed pré-definidos disponíveis após migration (is_padrao = true, company_id IS NULL)

### Execution

- [ ] **EXEC-01**: Usuário inicia checklist preenchendo identificação (responsável, local, data, número/código)
- [ ] **EXEC-02**: Usuário responde itens com todos os tipos suportados: Sim/Não, texto, número, data, múltipla escolha, foto
- [ ] **EXEC-03**: Usuário adiciona observação opcional por item
- [ ] **EXEC-04**: Usuário anexa foto(s) por item via câmera ou galeria
- [ ] **EXEC-05**: Rascunho salvo automaticamente durante preenchimento (falha silenciosa não interrompe o checklist)
- [ ] **EXEC-06**: Usuário assina digitalmente ao finalizar e o checklist é concluído

### History

- [ ] **HIST-01**: Usuário vê listagem de checklists realizados com filtros por data, tipo, responsável e local
- [ ] **HIST-02**: Usuário visualiza checklist concluído em modo leitura com todas as respostas e fotos
- [ ] **HIST-03**: Listagem exibe indicadores de conformidade (% conformidade, total de itens NOK)

### Navigation

- [ ] **NAV-01**: Entrada "Checklist" visível no drawer de navegação principal (acessível por todos os perfis)

## v2 Requirements (deferred)

### Reports

- **REP-01**: Usuário gera PDF com cabeçalho, identificação, itens (OK/NOK/N/A), fotos embutidas e assinatura
- **REP-02**: Usuário exporta e compartilha PDF via email ou WhatsApp

### Corrective Actions Integration

- **CAPA-CK-01**: Usuário cria ação corretiva vinculada a item NOK durante execução do checklist

## Out of Scope

| Feature | Reason |
|---------|--------|
| Relatório PDF (REP-01/02) | Complexidade: compute isolate, FileProvider Android, foto pre-fetch — v1.3 |
| Ações corretivas (CAPA) vinculadas a itens NOK | Fluxo pesado — integração com módulo de Auditoria planejada para v1.3 |
| Notificações para checklists atrasados | Requer cron job / FCM — v2+ |
| Checklist com escopo multi-empresa (superuser) | Admin feature — v2 |
| Modo offline com sync posterior | Alta complexidade — milestone futura |
| Ordenação por drag & drop de itens no builder | Cancelado em v1.1 no módulo de Auditoria — mesma decisão aqui |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TMPLCK-01 | Phase 13 | Pending |
| TMPLCK-02 | Phase 13 | Pending |
| TMPLCK-03 | Phase 13 | Pending |
| TMPLCK-04 | Phase 13 | Pending |
| TMPLCK-05 | Phase 13 | Pending |
| TMPLCK-06 | Phase 13 | Pending |
| NAV-01 | Phase 13 | Pending |
| EXEC-01 | Phase 14 | Pending |
| EXEC-02 | Phase 14 | Pending |
| EXEC-03 | Phase 14 | Pending |
| EXEC-04 | Phase 15 | Pending |
| EXEC-05 | Phase 14 | Pending |
| EXEC-06 | Phase 16 | Pending |
| HIST-01 | Phase 17 | Pending |
| HIST-02 | Phase 17 | Pending |
| HIST-03 | Phase 17 | Pending |

**Coverage:**
- v1.2 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-02*
*Last updated: 2026-05-02 — traceability confirmed against ROADMAP.md phases 13–17*
