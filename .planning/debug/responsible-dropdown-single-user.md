---
slug: responsible-dropdown-single-user
status: resolved
trigger: "Dropdown de responsável na tela de criar ação corretiva mostra apenas o usuário logado — outros membros da empresa não aparecem"
created: 2026-04-29
updated: 2026-04-29
---

# Debug Session: responsible-dropdown-single-user

## Symptoms

DATA_START
- expected: Dropdown mostra todos os membros ativos da empresa ativa, com possibilidade de selecionar qualquer um como responsável
- actual: Só aparece o usuário logado — apenas uma opção no dropdown
- error_messages: Nenhum erro visível na tela
- timeline: Identificado agora; não se sabe se já funcionou antes
- reproduction: Abrir tela de criar ação corretiva (CreateCorrectiveActionScreen) e verificar o campo de responsável
DATA_END

## Current Focus

- hypothesis: "RLS em profiles não tem policy SELECT para o role auditor ver outros perfis da empresa"
- test: "Verificar policies RLS em 20260418_rls_profiles_companies_perimeters.sql"
- expecting: "Apenas user_select_own cobre auditor — só retorna própria linha"
- next_action: "resolved"
- reasoning_checkpoint: "Dart code correto. Problema é na camada de banco de dados — policy ausente."
- tdd_checkpoint: ""

## Evidence

- timestamp: 2026-04-29T00:00:00Z
  file: primeaudit/lib/screens/create_corrective_action_screen.dart
  finding: "Chama _userService.getByCompany(companyId) corretamente em _load(). Código Dart sem defeito."

- timestamp: 2026-04-29T00:00:01Z
  file: primeaudit/lib/services/user_service.dart
  finding: "getByCompany() faz SELECT profiles WHERE company_id=X AND active=true. Query correta."

- timestamp: 2026-04-29T00:00:02Z
  file: primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql
  finding: |
    Policies em profiles:
      1. superuser_dev_profiles_full — superuser/dev acesso total
      2. adm_profiles_select         — adm lê company_id = get_my_company_id()
      3. adm_profiles_update         — adm atualiza própria empresa
      4. user_select_own             — ANY role: só lê própria linha (id = auth.uid())
    NENHUMA policy permite auditor ler outros perfis da empresa.
    Resultado: query de getByCompany() retorna apenas a linha do próprio usuário,
    porque user_select_own é a única policy que passa para auditor.

## Eliminated Hypotheses

- "Código Dart incorreto" — eliminado: screen e service estão corretos
- "CompanyContextService retorna null" — eliminado: há guarda explícita que mostraria erro de tela
- "Supabase lançou exception silenciosa" — eliminado: catch bloco mostraria _error na UI; tela renderizou o form

## Resolution

- root_cause: "Role 'auditor' não tem policy RLS SELECT em profiles além de user_select_own (somente própria linha). A query getByCompany() é filtrada pelo banco antes de qualquer filtro Dart, retornando apenas o usuário logado."
- fix: "Criada migration 20260429_rls_profiles_auditor_select_company.sql que adiciona policy 'auditor_profiles_select': auditor pode fazer SELECT em profiles WHERE company_id = get_my_company_id(). Nenhuma alteração no código Dart necessária."
- verification: "Após aplicar a migration no Supabase, abrir CreateCorrectiveActionScreen com role auditor e confirmar que todos os membros ativos da empresa aparecem no dropdown."
- files_changed:
  - primeaudit/supabase/migrations/20260429_rls_profiles_auditor_select_company.sql
