# PrimeAudit

## What This Is

App Flutter para realização de auditorias industriais em campo. Auditores executam checklists configuráveis por template, registrando respostas por item com cálculo automático de conformidade ponderada. O backend é Supabase (auth, banco, RLS) e o app suporta múltiplas empresas com RBAC por perfil.

## Core Value

Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

## Requirements

### Validated

- ✓ Autenticação email/senha com perfis RBAC (superuser, admin, auditor, viewer) — existente
- ✓ Scoping por empresa via CompanyContextService — existente
- ✓ Templates de auditoria com itens configuráveis (tipos: ok_nok, yes_no, scale_1_5, percentage, text, selection) — existente
- ✓ Fluxo completo de auditorias: criação (4 etapas), execução, encerramento/cancelamento — existente
- ✓ Cálculo de conformidade ponderado por peso e tipo de resposta — existente
- ✓ Seleção de perímetro hierárquico em cascata — existente
- ✓ Tema claro/escuro via ValueNotifier — existente
- ✓ Migrations SQL idempotentes para Supabase — existente

### Active

- [ ] Feedback de erro visível quando save de resposta falha (rede/timeout)
- [ ] Retry automático ou indicador de pendência para respostas não salvas
- [ ] Verificação e documentação das RLS policies do Supabase (quais tabelas, quais operações)
- [ ] Testes unitários para lógica crítica: calculateConformity, AppRole, fromMap dos models
- [ ] Correção do N+1 em reorderItems (batch update em vez de loop sequencial)
- [ ] Validação de CNPJ com checksum no formulário de registro
- [ ] Settings sincronizados com servidor (modo manutenção, config de auditoria)
- [ ] Enforçamento server-side de permissões em operações sensíveis (updateRole, updateCompany)

### Out of Scope

- Modo offline completo com sync posterior — complexidade alta, não é o foco desta milestone
- Relatórios em PDF / exportação — funcionalidade nova, não é parte da correção estrutural
- Notificações push — nova funcionalidade, fora do escopo

## Context

- App em desenvolvimento ativo, sem usuários reais ainda
- Codebase mapeado em 2026-04-16: arquitetura 3 camadas (screens → services → models), sem DI, sem BLoC/Riverpod
- Gerenciamento de estado: setState local + um ValueNotifier global (tema)
- Suporte a múltiplas empresas via CompanyContextService (singleton com SharedPreferences)
- Test suite: apenas scaffold Flutter padrão (contador inexistente) — zero cobertura real
- O risco mais crítico identificado: save silencioso de respostas em `audit_execution_screen.dart:228`

## Constraints

- **Stack**: Flutter + Dart + Supabase — sem trocar de stack nesta milestone
- **Estado**: Sem introduzir BLoC/Riverpod/Provider nesta milestone — refactor de estado é trabalho futuro separado
- **DB**: Migrações devem seguir padrão idempotente já estabelecido
- **Compatibilidade**: Não quebrar fluxos existentes (criação/execução/encerramento de auditorias)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Corrigir estrutura antes de novas features | App está em desenvolvimento; risco técnico alto se problemas forem para produção | — Pending |
| Manter setState como gerenciamento de estado | Refactor completo é milestone separada, não misturar com correção de bugs | — Pending |
| RLS como camada de segurança principal | anon key é public by design no Supabase; segurança depende de RLS correto | — Pending |

## Evolution

Este documento evolui a cada transição de fase e milestone.

**Após cada fase** (via `/gsd-transition`):
1. Requirements invalidados? → Mover para Out of Scope com motivo
2. Requirements validados? → Mover para Validated com referência da fase
3. Novos requirements? → Adicionar em Active
4. Decisões a registrar? → Adicionar em Key Decisions
5. "What This Is" ainda preciso? → Atualizar se driftar

**Após cada milestone** (via `/gsd-complete-milestone`):
1. Revisão completa de todas as seções
2. Core Value check — ainda é a prioridade certa?
3. Auditar Out of Scope — motivos ainda válidos?
4. Atualizar Context com estado atual

---
*Last updated: 2026-04-16 after initialization*
