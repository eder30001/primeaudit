---
phase: 02-security
verified: 2026-04-18T00:00:00Z
status: human_needed
score: 11/12
overrides_applied: 0
human_verification:
  - test: "Executar supabase db push e confirmar que ambas as migrations aparecem como aplicadas via supabase migration list"
    expected: "Output de migration list lista 20260418_fix_active_guard e 20260418_rls_profiles_companies_perimeters como aplicadas no banco remoto"
    why_human: "Plan 04 Task 1 (supabase db push) exige autenticacao CLI com sessao interativa ou SUPABASE_ACCESS_TOKEN — nao pode ser verificado localmente. A SUMMARY afirma que foi feito, mas a verificacao programatica de migracao remota nao e possivel sem acesso CLI autenticado."
---

# Phase 2: Security — Verification Report

**Phase Goal:** RLS protege dados no servidor independente do cliente, e entradas invalidas sao rejeitadas antes de chegar ao banco
**Verified:** 2026-04-18
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Existe documento listando todas as tabelas com RLS habilitado, policies cobertas e resultado de teste manual de cada policy critica (SC-1 / SEC-01) | VERIFIED | `primeaudit/SECURITY-AUDIT.md` existe com todas 8 tabelas documentadas, policies listadas por tabela, e 9 verificacoes manuais preenchidas (9x `passed`) |
| 2 | Um usuario autenticado como `auditor` que chame updateRole diretamente recebe erro do Supabase — operacao bloqueada por RLS nao pela UI (SC-2 / SEC-02) | VERIFIED | `adm_profiles_update` WITH CHECK subquery `role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)` esta no SQL da migration; SECURITY-AUDIT.md linha 6 marca `passed`; auditores sem policy de UPDATE em profiles tambem sao bloqueados via ausencia de policy de UPDATE |
| 3 | Usuario com `active = false` com JWT valido nao consegue ler registros de nenhuma tabela protegida (SC-3 / SEC-03) | VERIFIED | `get_my_role()` e `get_my_company_id()` reescritas com `AND active = true` em `20260418_fix_active_guard.sql`; efeito cascata via `NULL IN (...)` = false em todas policies; verificacoes manuais 2-4 marcadas `passed` em SECURITY-AUDIT.md |
| 4 | Campo CNPJ rejeita CNPJ com comprimento correto mas digitos verificadores invalidos, exibindo mensagem de erro antes de chamada ao banco (SC-4 / SEC-04) | VERIFIED | `cnpj_validator.dart` implementa algoritmo completo Receita Federal com pesos w1/w2; `validateCnpj` retorna mensagem de erro especifica; wired em `register_screen.dart:312` e `company_form.dart:144` via `validator: validateCnpj` |
| 5 | `get_my_role()` retorna NULL quando `profiles.active = false` | VERIFIED | `20260418_fix_active_guard.sql` linha 17: `SELECT role FROM profiles WHERE id = auth.uid() AND active = true` — retorna NULL para inativos |
| 6 | `get_my_company_id()` retorna NULL quando `profiles.active = false` | VERIFIED | `20260418_fix_active_guard.sql` linha 27: `SELECT company_id FROM profiles WHERE id = auth.uid() AND active = true` — retorna NULL para inativos |
| 7 | Nenhuma policy existente em audits/audit_answers e modificada — mudanca cascata via funcao | VERIFIED | `20260418_fix_active_guard.sql` nao contem CREATE POLICY nem DROP POLICY; apenas as duas funcoes sao reescritas |
| 8 | A migration de funcoes e idempotente: pode ser re-executada sem erro | VERIFIED | Usa `CREATE OR REPLACE FUNCTION` — nao requer DROP; semanticamente idempotente |
| 9 | profiles, companies, perimeters, audit_types, audit_templates, template_items tem RLS habilitado e policies corretas usando get_my_role() | VERIFIED | `20260418_rls_profiles_companies_perimeters.sql` contem 6x `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` e 19 CREATE POLICY — todas usam `get_my_role()` ou `get_my_company_id()` |
| 10 | `adm` nao pode alterar `profiles.role` — policy WITH CHECK bloqueia mudanca da coluna role | VERIFIED | `adm_profiles_update` WITH CHECK contem subquery `role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)`; verificacao manual 6 marcada `passed` |
| 11 | Funcao `isValidCnpj(String)` retorna true somente se os dois digitos verificadores conferem | VERIFIED | Implementacao em `cnpj_validator.dart` com pesos w1=[5,4,3,2,9,8,7,6,5,4,3,2] e w2=[6,5,4,3,2,9,8,7,6,5,4,3,2]; 16 testes unitarios cobrindo casos validos, checksums invalidos, sequencias repetidas, comprimento errado |
| 12 | Ambas as migrations aplicadas no banco remoto (supabase db push executado) | UNCERTAIN | SUMMARY 02-04 afirma que o push foi executado e todos os 9 testes manuais passaram; nao e possivel verificar o estado remoto programaticamente sem acesso CLI autenticado |

**Score:** 11/12 truths verified (1 uncertain — requer verificacao humana)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `primeaudit/supabase/migrations/20260418_fix_active_guard.sql` | SECURITY DEFINER function fixes for active-user guard (SEC-03) | VERIFIED | Existe; contem 2x `CREATE OR REPLACE FUNCTION` com `AND active = true`; 33 linhas; sem CREATE/DROP POLICY |
| `primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql` | Idempotent RLS migration for 6 tables (SEC-01, SEC-02) | VERIFIED | Existe; 6x ENABLE ROW LEVEL SECURITY; 19 CREATE POLICY; 22 DROP POLICY IF EXISTS; sem `role = 'admin'`; sem `auth.jwt() ->> 'role'` |
| `primeaudit/SECURITY-AUDIT.md` | RLS documentation artifact with 9 manual test results | VERIFIED | Existe na raiz de `primeaudit/`; todas 8 tabelas documentadas; 9 verificacoes preenchidas com `passed`; sem `pending` em linhas de dados (apenas na legenda) |
| `primeaudit/lib/core/cnpj_validator.dart` | Pure Dart CNPJ checksum validation (SEC-04) | VERIFIED | Existe; top-level functions `isValidCnpj(String)` e `validateCnpj(String?)`; sem imports Flutter ou Supabase; pesos w1 e w2 corretos |
| `primeaudit/test/core/cnpj_validator_test.dart` | 16 unit tests covering valid CNPJs, invalid checksums, length, same-digit, empty | VERIFIED | Existe; 16 test() calls (10 para isValidCnpj, 6 para validateCnpj); import correto `package:primeaudit/core/cnpj_validator.dart` |
| `primeaudit/lib/screens/register_screen.dart` | CNPJ TextFormField with validator: validateCnpj wired | VERIFIED | Linha 5: `import '../core/cnpj_validator.dart';`; linha 312: `validator: validateCnpj,`; linha 310: `onChanged: _searchCompany,` preservado |
| `primeaudit/lib/screens/admin/company_form.dart` | CNPJ _buildField with validator: validateCnpj | VERIFIED | Linha 4: `import '../../core/cnpj_validator.dart';`; linha 144: `validator: validateCnpj,` dentro do _buildField do CNPJ |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `get_my_role()` | `profiles.active column` | `AND active = true` predicate in WHERE clause | WIRED | Linha 17: `WHERE id = auth.uid() AND active = true` confirmado |
| `get_my_company_id()` | `profiles.active column` | `AND active = true` predicate in WHERE clause | WIRED | Linha 27: `WHERE id = auth.uid() AND active = true` confirmado |
| `profiles UPDATE adm policy` | role column immutability | WITH CHECK subquery comparing proposed role with current role | WIRED | `AND role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)` na linha 45 da migration |
| `perimeters/audit_types/audit_templates/template_items policies` | `get_my_role() + get_my_company_id()` | SECURITY DEFINER function calls | WIRED | Todas as 12 policies nessas tabelas usam `get_my_role()` — nenhuma usa role diretamente |
| `register_screen.dart CNPJ TextFormField` | `cnpj_validator.dart validateCnpj` | direct import + validator parameter | WIRED | Import em linha 5; `validator: validateCnpj,` em linha 312 |
| `company_form.dart _buildField for CNPJ` | `cnpj_validator.dart validateCnpj` | direct import + validator parameter | WIRED | Import em linha 4; `validator: validateCnpj,` em linha 144 |

---

### Data-Flow Trace (Level 4)

Not applicable for this phase. Phase 2 delivers SQL migrations and a pure Dart validation utility — no components that render dynamic data from a fetch/store.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `isValidCnpj` e `validateCnpj` sao funcoes top-level exportadas | `grep -c "bool isValidCnpj\|String? validateCnpj" primeaudit/lib/core/cnpj_validator.dart` | 2 matches | PASS |
| Migration de funcoes nao toca policies | `grep "CREATE POLICY\|DROP POLICY" primeaudit/supabase/migrations/20260418_fix_active_guard.sql` | NONE | PASS |
| Migration RLS nao usa role='admin' | `grep "role = 'admin'" primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql` | NOT FOUND | PASS |
| Migration RLS cobre 6 tabelas (ENABLE RLS) | `grep -c "ENABLE ROW LEVEL SECURITY" ...rls_profiles_companies_perimeters.sql` | 6 | PASS |
| 16 testes unitarios criados | `grep -c "test(" primeaudit/test/core/cnpj_validator_test.dart` | 16 | PASS |
| supabase db push remoto | Verificacao de banco remoto via CLI autenticada | Nao verificavel programaticamente | SKIP — requer acesso CLI autenticado |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| SEC-01 | 02-02, 02-04 | Todas as tabelas Supabase com RLS documentadas, policies verificadas e registradas | SATISFIED | `SECURITY-AUDIT.md` lista 8 tabelas; 9 verificacoes manuais preenchidas (todas `passed`); migration com 6 tabelas cobertas |
| SEC-02 | 02-02, 02-04 | `updateRole` protegido por RLS — nao-admin nao escala proprio privilegio | SATISFIED | `adm_profiles_update` WITH CHECK subquery bloqueia mudanca de role; verificacoes 5 e 6 marcadas `passed` |
| SEC-03 | 02-01, 02-04 | Usuario `active = false` nao consegue ler dados com JWT valido | SATISFIED | `get_my_role()` e `get_my_company_id()` com `AND active = true`; verificacoes 1-4 marcadas `passed` |
| SEC-04 | 02-03 | Campo CNPJ valida checksum (digitos verificadores), nao so comprimento | SATISFIED | `cnpj_validator.dart` com algoritmo Receita Federal; wired em ambos os formularios com `validator: validateCnpj` |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | — |

No anti-patterns found. Verificacoes especificas:
- Nenhuma policy usa `role = 'admin'` (role inexistente)
- Nenhuma policy usa `auth.jwt() ->> 'role'` (stale JWT anti-pattern)
- `cnpj_validator.dart` sem imports Flutter/Supabase (puro Dart)
- Nenhum `TODO/FIXME/PLACEHOLDER` nos arquivos entregues
- `onChanged: _searchCompany` preservado em register_screen (nao removido junto com o validator)

---

### Human Verification Required

#### 1. Confirmar Migrações Aplicadas no Banco Remoto

**Test:** Executar `cd primeaudit && supabase migration list` em uma shell autenticada com `SUPABASE_ACCESS_TOKEN` ou apos `supabase login`.

**Expected:** Output lista `20260418_fix_active_guard` e `20260418_rls_profiles_companies_perimeters` como Applied (ou equivalente indicando sincronizacao remota).

**Why human:** A verificacao do estado remoto do banco requer acesso CLI autenticado ao projeto Supabase. O arquivo `SECURITY-AUDIT.md` ja foi preenchido com os 9 resultados `passed` pelo Plan 04, indicando que a execucao ocorreu. A SUMMARY do Plan 04 documenta o sucesso. Porem, nao ha como confirmar o estado do banco remoto sem a CLI autenticada — isso e um item de validacao final que o desenvolvedor pode confirmar com um unico comando.

**Note:** Se `supabase migration list` confirmar ambas as migrations como aplicadas, o status desta verificacao pode ser marcado como `passed` e a fase esta completamente verificada (score 12/12). Se nao confirmado, os artefatos locais estao corretos mas o banco remoto pode nao refletir as correcoes de segurança.

---

### Gaps Summary

Sem gaps bloqueantes. Todos os artefatos locais estao completos, substantivos e corretamente conectados. Os 4 requisitos de segurança (SEC-01, SEC-02, SEC-03, SEC-04) possuem implementacao verificavel no codigo.

O unico item incerto e a confirmacao do `supabase db push` no banco remoto — operacao documentada como executada na SUMMARY do Plan 04 e evidenciada pelos 9 resultados manuais passados no SECURITY-AUDIT.md (que so podem ter sido preenchidos apos o push). Este item nao bloqueia a aprovacao dos artefatos locais mas requer confirmacao humana de acordo com o criterio de verificacao.

---

_Verified: 2026-04-18_
_Verifier: Claude (gsd-verifier)_
