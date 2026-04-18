-- =============================================================================
-- Migração: Corrigir guarda de active=false em SECURITY DEFINER functions (SEC-03)
-- Data: 2026-04-18
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- Referência: Phase 02-security, D-04 + D-05
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. get_my_role() — adiciona AND active = true
-- ----------------------------------------------------------------------------
-- Substitui a versão de 20260406_create_audits.sql (sem guarda de active).
-- Retorna NULL quando profiles.active = false, fazendo com que todas as
-- policies existentes (audits, audit_answers) e novas neguem acesso
-- automaticamente via NULL IN (...) = false.
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM profiles WHERE id = auth.uid() AND active = true;
$$;

-- ----------------------------------------------------------------------------
-- 2. get_my_company_id() — adiciona AND active = true
-- ----------------------------------------------------------------------------
-- Mesma guarda, por consistência (D-05). Usuário inativo não resolve company
-- context — nenhuma policy baseada em get_my_company_id() passa.
CREATE OR REPLACE FUNCTION get_my_company_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT company_id FROM profiles WHERE id = auth.uid() AND active = true;
$$;

-- ----------------------------------------------------------------------------
-- 3. Recarregar schema cache do PostgREST
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
