# Roadmap: PrimeAudit — Correção Estrutural

## Overview

Esta milestone corrige os riscos técnicos mais críticos antes que o app chegue a usuários reais. A ordem das fases reflete risco: dados primeiro (perda silenciosa de respostas), depois segurança (RBAC e RLS), depois qualidade via testes que cobrem o código corrigido, depois performance (N+1), e por fim configuração server-side. Nenhuma feature nova é adicionada — cada fase entrega confiabilidade verificável.

## Phases

- [x] **Phase 1: Data Integrity** - Tornar falhas de save visíveis e recuperáveis para o auditor (completed 2026-04-17)
- [ ] **Phase 2: Security** - Garantir que RLS, RBAC e validações de entrada bloqueiem acesso indevido
- [ ] **Phase 3: Test Coverage** - Cobrir lógica crítica com testes unitários verificáveis
- [ ] **Phase 4: Performance** - Eliminar o N+1 em reorderItems com batch update
- [ ] **Phase 5: Server Config** - Mover configurações críticas do dispositivo para o servidor

## Phase Details

### Phase 1: Data Integrity
**Goal**: O auditor nunca perde uma resposta sem saber — falhas de save são visíveis e recuperáveis
**Depends on**: Nothing (first phase)
**Requirements**: DINT-01, DINT-02, DINT-03
**Success Criteria** (what must be TRUE):
  1. Quando `upsertAnswer` falha por rede ou timeout, o item exibe um indicador visual de erro (borda vermelha ou ícone) — o auditor vê que aquela resposta não foi salva
  2. Enquanto uma resposta aguarda confirmação do servidor, o item exibe um indicador "pendente" (spinner ou ícone) distinto do estado salvo
  3. O auditor pode tocar num item com falha e tentar re-salvar manualmente sem precisar reiniciar a tela ou fechar a auditoria
  4. O `catch` vazio em `audit_execution_screen.dart:228` não existe mais — erros de save são capturados, logados e propagados para a UI
**Plans**: 3 plans
Plans:
- [x] 01-01-PLAN.md — Wave 0: extrair PendingSave para classe pública + criar scaffolds de teste (pending_save_test.dart, audit_execution_save_error_test.dart) e remover smoke test quebrado
- [x] 01-02-PLAN.md — Wave 1: corrigir _saveAnswer (remover catch silencioso), implementar _showSaveError + _scheduleRetry com backoff exponencial, inserir guarda D-06 em _finalize
- [x] 01-03-PLAN.md — Wave 2: preencher unit tests de PendingSave e widget tests da guarda D-06; DINT-01/DINT-03 manual-only documentados
**UI hint**: no

### Phase 2: Security
**Goal**: RLS protege dados no servidor independente do cliente, e entradas inválidas são rejeitadas antes de chegar ao banco
**Depends on**: Phase 1
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04
**Success Criteria** (what must be TRUE):
  1. Existe documento (ou comentário em `supabase_config.dart`) listando todas as tabelas com RLS habilitado, quais operações cada policy cobre, e o resultado de teste manual de cada policy crítica
  2. Um usuário autenticado como `auditor` que chame `UserService.updateRole()` diretamente (sem UI) recebe erro do Supabase — a operação é bloqueada por RLS, não pela UI
  3. Um usuário com `active = false` que possua um JWT válido não consegue ler registros de nenhuma tabela protegida — o RLS nega o acesso mesmo com sessão ativa
  4. O campo CNPJ no formulário de registro rejeita um CNPJ com comprimento correto mas dígitos verificadores inválidos, exibindo mensagem de erro antes de qualquer chamada ao banco
**Plans**: TBD
**UI hint**: no

### Phase 3: Test Coverage
**Goal**: A lógica de negócio crítica do app tem cobertura de testes unitários verificável por `flutter test`
**Depends on**: Phase 2
**Requirements**: QUAL-01, QUAL-02, QUAL-03, QUAL-04
**Success Criteria** (what must be TRUE):
  1. `flutter test` passa sem falhas — o scaffold de contador quebrado foi removido ou substituído
  2. `AuditAnswerService.calculateConformity()` tem testes cobrindo todos os tipos de resposta (`ok_nok`, `yes_no`, `scale_1_5`, `percentage`, `text`, `selection`) com pelo menos dois valores de peso distintos, incluindo o caso de lista vazia
  3. `AppRole` tem testes verificando `canAccessAdmin`, `canEdit` e demais helpers para cada role (`superuser`, `dev`, `adm`, `auditor`, `anonymous`)
  4. Os `fromMap()` dos 7 models listados (`Audit`, `AuditAnswer`, `AuditTemplate`, `TemplateItem`, `Perimeter`, `Company`, `UserProfile`) têm testes que parsam um mapa válido e verificam campos críticos
  5. `Perimeter.buildTree()` tem testes cobrindo hierarquias de 1, 2 e 3 níveis de profundidade, incluindo nó sem filhos e lista vazia
**Plans**: TBD
**UI hint**: no

### Phase 4: Performance
**Goal**: Reordenar itens de template não causa N queries sequenciais ao banco
**Depends on**: Phase 3
**Requirements**: PERF-01
**Success Criteria** (what must be TRUE):
  1. `AuditTemplateService.reorderItems()` não contém `await` dentro de `for` loop — o loop sequencial foi substituído por uma operação batch (seja `Future.wait`, Edge Function, ou `UPDATE ... FROM VALUES`)
  2. Reordenar 20 itens em um template emite no máximo 1 query ao Supabase (ou queries paralelas — não sequenciais bloqueantes)
  3. O comportamento visual de reordenação na tela de template builder continua funcionando após a mudança
**Plans**: TBD
**UI hint**: no

### Phase 5: Server Config
**Goal**: Configurações críticas do sistema são lidas do servidor e têm efeito em todos os dispositivos
**Depends on**: Phase 4
**Requirements**: CONF-01
**Success Criteria** (what must be TRUE):
  1. Existe uma tabela no Supabase (ex: `company_settings` ou `system_config`) que armazena pelo menos `maintenance_mode` e as configurações de auditoria atualmente locais
  2. Quando um admin habilita "modo manutenção" no seu dispositivo, um auditor em outro dispositivo vê o efeito ao abrir o app (não apenas no dispositivo do admin)
  3. `SettingsService` lê as configurações críticas do Supabase no startup, com fallback para os valores locais caso a leitura falhe — o app não quebra offline
**Plans**: TBD
**UI hint**: no

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Data Integrity | 3/3 | Complete   | 2026-04-17 |
| 2. Security | 0/? | Not started | - |
| 3. Test Coverage | 0/? | Not started | - |
| 4. Performance | 0/? | Not started | - |
| 5. Server Config | 0/? | Not started | - |
