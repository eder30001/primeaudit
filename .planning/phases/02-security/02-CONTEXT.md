# Phase 2: Security - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Garantir que RLS, RBAC e validações de entrada bloqueiem acesso indevido. Não adiciona features novas — só corrige gaps de segurança: políticas RLS ausentes/incorretas, usuários inativos bypassando RLS, e CNPJ sem validação de checksum.

</domain>

<decisions>
## Implementation Decisions

### CNPJ Validation (SEC-04)
- **D-01:** Validar checksum do CNPJ (dígitos verificadores) em **dois pontos**: `register_screen.dart` (cadastro de usuário) e `company_form.dart` (admin criando empresa).
- **D-02:** Lógica de validação extraída para `primeaudit/lib/core/cnpj_validator.dart` — arquivo dedicado, reutilizável pelas duas telas, testável unitariamente. Segue padrão de `lib/core/` para utilitários globais.
- **D-03:** Validação acontece no `validator` do `TextFormField` — antes de qualquer chamada ao banco. Sem validação server-side (desnecessária dado que os dois pontos de entrada são cobertos).

### active=false RLS Enforcement (SEC-03)
- **D-04:** Modificar a função `get_my_role()` para retornar `NULL` quando `profiles.active = false`. Uma única mudança cobre automaticamente todas as policies existentes (audits, audit_answers, e as novas policies a criar) sem precisar alterar cada policy individualmente.
- **D-05:** Modificar também `get_my_company_id()` com a mesma guarda de `active` para consistência.

### RLS Audit Scope (SEC-01 + SEC-02)
- **D-06:** Auditar e criar policies RLS para **todas** as tabelas do sistema. As tabelas `perimeters`, `audit_templates`, `audit_types`, `template_items` não têm nenhuma policy — gap crítico a fechar.
- **D-07:** As policies de `profiles` e `companies` no `schema.sql` atual referenciam `role = 'admin'` (role inexistente) — devem ser substituídas por policies corretas usando `get_my_role()`.
- **D-08:** Para `profiles` UPDATE: apenas `superuser`/`dev` podem alterar `role` de qualquer usuário; `adm` pode alterar apenas `full_name` e `active` de usuários da sua empresa — não pode escalar privilégio (SEC-02).
- **D-09:** Todas as migrations seguem o padrão idempotente estabelecido (`DROP POLICY IF EXISTS` + `CREATE POLICY`).

### RLS Documentation (SEC-01)
- **D-10:** Documento de auditoria: `primeaudit/SECURITY-AUDIT.md` — lista cada tabela, se RLS está habilitado, quais operações cada policy cobre, e resultado de teste manual das policies críticas.

### Claude's Discretion
- Ordem exata de criação das migrations (uma por tabela ou consolidada)
- Policies para `audit_types` e `audit_templates`: se templates globais (`company_id IS NULL`) são visíveis para todos os roles autenticados
- Estrutura interna do `cnpj_validator.dart` (função pura vs. classe estática)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Migrations existentes (RLS já implementado)
- `primeaudit/supabase/migrations/20260406_create_audits.sql` — policies completas para `audits`; contém `get_my_role()` e `get_my_company_id()` SECURITY DEFINER — modificar aqui para adicionar guarda `active`
- `primeaudit/lib/supabase/migrations/20260406_create_audit_answers.sql` — policies completas para `audit_answers`

### Schema base (policies quebradas a substituir)
- `primeaudit/supabase/schema.sql` — linhas 44-55: policies de `profiles` e `companies` com `role = 'admin'` (inexistente) — referência para entender o que precisa ser corrigido, NÃO como modelo

### Serviços com operações sensíveis (SEC-02)
- `primeaudit/lib/services/user_service.dart` — `updateRole()` e `updateCompany()` sem proteção server-side hoje; RLS na tabela `profiles` é o que vai bloquear

### Telas com campo CNPJ (SEC-04)
- `primeaudit/lib/screens/register_screen.dart` — `_searchCompany()` só checa comprimento (`clean.length < 14`); validator do campo não existe — adicionar
- `primeaudit/lib/screens/admin/company_form.dart` — verificar campo CNPJ e adicionar validação

### Padrões de core/
- `primeaudit/lib/core/app_roles.dart` — padrão de utilitário global; `cnpj_validator.dart` deve seguir o mesmo estilo

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `get_my_role()` / `get_my_company_id()` — funções SECURITY DEFINER já usadas em todas as policies de `audits` e `audit_answers`; modificar aqui para adicionar guarda `active` é o ponto central do SEC-03
- `AppRole` em `lib/core/app_roles.dart` — constantes de role (`superuser`, `dev`, `adm`, `auditor`, `anonymous`) a referenciar nas novas policies SQL

### Established Patterns
- Migrations idempotentes: `DROP POLICY IF EXISTS` antes de `CREATE POLICY`; `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
- Policies seguem estrutura: superuser/dev → acesso total; adm → escopo empresa; auditor → escopo empresa + próprias auditorias
- `TextFormField` com `validator:` para validação de formulário (padrão já usado para email, senha, nome em `register_screen.dart`)

### Integration Points
- `get_my_role()` em `20260406_create_audits.sql` — ponto de modificação para SEC-03 (adicionar `AND active = true` à query interna)
- `_cnpjController` em `register_screen.dart` — adicionar `validator:` ao campo existente
- `company_form.dart` — verificar campo CNPJ e adicionar validator

</code_context>

<specifics>
## Specific Ideas

- `get_my_role()` corrigido: `SELECT role FROM profiles WHERE id = auth.uid() AND active = true` — se inativo, retorna NULL, e nenhuma policy com `USING (get_my_role() IN (...))` vai passar
- `cnpj_validator.dart` deve expor uma função pura `bool isValidCnpj(String cnpj)` e uma string `validateCnpj(String? value)` compatível com o `validator:` do TextFormField

</specifics>

<deferred>
## Deferred Ideas

- **Dashboard com dados reais nos cards** — nova feature (exibir métricas de auditoria no HomeScreen); fase própria após Test Coverage
- **Bottom navigation bar** — refactor de navegação: mover menu lateral para tab bar inferior visível apenas no dashboard, mantendo só Settings e Perfil no drawer; fase de UI separada
- Validação server-side de CNPJ via Supabase function/trigger — desnecessária dado cobertura nos dois pontos de entrada Flutter

</deferred>

---

*Phase: 02-security*
*Context gathered: 2026-04-17*
