-- =============================================================================
-- Migração: Permitir auditor visualizar perfis da própria empresa (fix dropdown)
-- Data: 2026-04-29
-- Idempotente: pode ser executado múltiplas vezes sem erro.
--
-- Problema: A tela CreateCorrectiveActionScreen chama getByCompany() para
-- popular o dropdown de responsável, mas o role 'auditor' não tinha policy
-- SELECT em profiles além de 'user_select_own' (somente o próprio perfil).
-- Resultado: apenas o usuário logado aparecia no dropdown.
--
-- Solução: Adicionar policy que permite auditor ler perfis ativos da mesma
-- empresa, espelhando o comportamento já existente para 'adm'.
-- =============================================================================

DROP POLICY IF EXISTS "auditor_profiles_select" ON profiles;

-- auditor: lê perfis ativos da própria empresa
-- (mesma restrição que adm_profiles_select, sem acesso a update/delete)
CREATE POLICY "auditor_profiles_select" ON profiles FOR SELECT
  USING (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
  );

-- Recarregar schema cache do PostgREST
NOTIFY pgrst, 'reload schema';
