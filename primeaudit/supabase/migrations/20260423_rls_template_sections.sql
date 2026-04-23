-- =============================================================================
-- Migração: RLS policies para template_sections
-- Data: 2026-04-23
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- Contexto: template_sections não tinha RLS habilitado, causando falha silenciosa
--           em UPDATE de order_index durante reordenação drag & drop (TMPL-02).
--           Escopo idêntico ao de template_items: acesso via audit_templates.
-- =============================================================================

DROP POLICY IF EXISTS "superuser_dev_template_sections_full"      ON template_sections;
DROP POLICY IF EXISTS "adm_template_sections_company"             ON template_sections;
DROP POLICY IF EXISTS "authenticated_template_sections_select"    ON template_sections;

ALTER TABLE template_sections ENABLE ROW LEVEL SECURITY;

-- superuser e dev: acesso total
CREATE POLICY "superuser_dev_template_sections_full" ON template_sections
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: gerencia seções de templates da própria empresa
CREATE POLICY "adm_template_sections_company" ON template_sections
  USING (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audit_templates t
      WHERE t.id = template_sections.template_id
        AND t.company_id = get_my_company_id()
    )
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audit_templates t
      WHERE t.id = template_sections.template_id
        AND t.company_id = get_my_company_id()
    )
  );

-- qualquer usuário ativo autenticado: SELECT de seções de templates globais ou da própria empresa
CREATE POLICY "authenticated_template_sections_select" ON template_sections FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM audit_templates t
      WHERE t.id = template_sections.template_id
        AND (t.company_id IS NULL OR t.company_id = get_my_company_id())
    )
  );
