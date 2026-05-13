-- =============================================================================
-- Migração: coluna corrective_action_id em audit_item_images + policy UPDATE auditor
-- Data: 2026-05-12
-- Idempotente: pode ser executado múltiplas vezes sem erro.
--
-- Problema: coluna foi adicionada manualmente no banco anterior e não constava
-- em nenhuma migration. O link entre imagem e ação corretiva falha em bancos
-- criados apenas pelas migrations existentes.
-- =============================================================================

-- 1. Coluna (idempotente)
ALTER TABLE audit_item_images
  ADD COLUMN IF NOT EXISTS corrective_action_id UUID;

-- 2. FK para corrective_actions (drop + add para idempotência)
ALTER TABLE audit_item_images
  DROP CONSTRAINT IF EXISTS audit_item_images_corrective_action_id_fkey;

ALTER TABLE audit_item_images
  ADD CONSTRAINT audit_item_images_corrective_action_id_fkey
  FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id) ON DELETE SET NULL;

-- 3. Index para consultas por ação corretiva
CREATE INDEX IF NOT EXISTS idx_audit_item_images_corrective_action_id
  ON audit_item_images (corrective_action_id)
  WHERE corrective_action_id IS NOT NULL;

-- 4. Policy UPDATE para auditor (permite vincular imagens à própria ação corretiva)
DROP POLICY IF EXISTS "auditor_audit_item_images_update" ON audit_item_images;
CREATE POLICY "auditor_audit_item_images_update" ON audit_item_images
  FOR UPDATE
  USING (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  )
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );

NOTIFY pgrst, 'reload schema';
