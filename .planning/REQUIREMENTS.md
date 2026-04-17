# Requirements: PrimeAudit — Correção Estrutural

**Defined:** 2026-04-16
**Core Value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## v1 Requirements

### Integridade de Dados (DINT)

- [x] **DINT-01**: Auditor vê mensagem de erro quando save de resposta falha por rede ou timeout
- [x] **DINT-02**: App exibe indicador visual de resposta "pendente" enquanto aguarda confirmação do servidor
- [x] **DINT-03**: Auditor pode tentar re-salvar manualmente respostas que falharam

### Segurança (SEC)

- [ ] **SEC-01**: Todas as tabelas Supabase com RLS documentadas — políticas verificadas e registradas
- [ ] **SEC-02**: `updateRole` e `updateCompany` protegidos por RLS — usuário não-admin não consegue escalar próprio privilégio
- [ ] **SEC-03**: Usuário com `active = false` não consegue ler dados mesmo com JWT emitido
- [ ] **SEC-04**: Campo CNPJ no registro valida checksum (dígitos verificadores), não só comprimento

### Qualidade (QUAL)

- [ ] **QUAL-01**: `AuditAnswerService.calculateConformity()` coberto por testes unitários com todos os tipos de resposta e pesos
- [ ] **QUAL-02**: `AppRole` (canAccessAdmin, canEdit, etc.) coberto por testes unitários para cada role
- [ ] **QUAL-03**: `fromMap()` de todos os models cobertos por testes unitários (Audit, AuditAnswer, AuditTemplate, TemplateItem, Perimeter, Company, UserProfile)
- [ ] **QUAL-04**: `Perimeter.buildTree()` coberto por testes unitários incluindo hierarquias profundas

### Performance (PERF)

- [ ] **PERF-01**: `AuditTemplateService.reorderItems()` usa batch update (single query) em vez de N queries sequenciais por item

### Configuração (CONF)

- [ ] **CONF-01**: Configurações críticas (modo manutenção, configurações de auditoria) são lidas do servidor (Supabase), não apenas do dispositivo local

## v2 Requirements

### Offline

- **OFFL-01**: App funciona sem internet e sincroniza respostas quando conexão é restaurada
- **OFFL-02**: Conflitos de sync são resolvidos com política "last-write-wins" por item

### Relatórios

- **REPT-01**: Auditor pode exportar laudo de auditoria em PDF
- **REPT-02**: Admin pode gerar relatório consolidado de conformidade por período

## Out of Scope

| Feature | Reason |
|---------|--------|
| Modo offline completo com sync | Alta complexidade, não é o foco desta milestone de correção estrutural |
| Relatórios PDF / exportação | Nova funcionalidade, fora do escopo de correção |
| Notificações push | Nova funcionalidade, fora do escopo de correção |
| Refactor de gerenciamento de estado (BLoC/Riverpod) | Trabalho de refactor separado, não misturar com correção de bugs |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DINT-01 | Phase 1 | Complete |
| DINT-02 | Phase 1 | Complete |
| DINT-03 | Phase 1 | Complete |
| SEC-01 | Phase 2 | Pending |
| SEC-02 | Phase 2 | Pending |
| SEC-03 | Phase 2 | Pending |
| SEC-04 | Phase 2 | Pending |
| QUAL-01 | Phase 3 | Pending |
| QUAL-02 | Phase 3 | Pending |
| QUAL-03 | Phase 3 | Pending |
| QUAL-04 | Phase 3 | Pending |
| PERF-01 | Phase 4 | Pending |
| CONF-01 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-04-16 after roadmap creation*
