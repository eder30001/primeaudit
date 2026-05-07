-- =============================================================================
-- Migracao: tabela checklist_item_images + bucket checklist-images (Storage)
-- Data: 2026-05-10
-- Idempotente: pode ser executado multiplas vezes sem erro.
-- Modulo Checklist independente — sem referencia a audit_item_images ou ImageService.
-- =============================================================================

-- 1. Tabela base
CREATE TABLE IF NOT EXISTS checklist_item_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

-- 2. Colunas (idempotentes, com DEFAULT para satisfazer NOT NULL no ADD COLUMN IF NOT EXISTS)
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS execution_id  UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS item_id       UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS company_id    UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS storage_path  TEXT NOT NULL DEFAULT '';
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS created_by    UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 3. Foreign keys (drop + add para idempotencia)
ALTER TABLE checklist_item_images DROP CONSTRAINT IF EXISTS checklist_item_images_execution_id_fkey;
ALTER TABLE checklist_item_images ADD CONSTRAINT checklist_item_images_execution_id_fkey
  FOREIGN KEY (execution_id) REFERENCES checklist_executions(id) ON DELETE CASCADE;

ALTER TABLE checklist_item_images DROP CONSTRAINT IF EXISTS checklist_item_images_item_id_fkey;
ALTER TABLE checklist_item_images ADD CONSTRAINT checklist_item_images_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES checklist_template_items(id) ON DELETE CASCADE;

ALTER TABLE checklist_item_images DROP CONSTRAINT IF EXISTS checklist_item_images_company_id_fkey;
ALTER TABLE checklist_item_images ADD CONSTRAINT checklist_item_images_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;

ALTER TABLE checklist_item_images DROP CONSTRAINT IF EXISTS checklist_item_images_created_by_fkey;
ALTER TABLE checklist_item_images ADD CONSTRAINT checklist_item_images_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE RESTRICT;

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_checklist_item_images_execution_item
  ON checklist_item_images (execution_id, item_id);
CREATE INDEX IF NOT EXISTS idx_checklist_item_images_company_id
  ON checklist_item_images (company_id);
CREATE INDEX IF NOT EXISTS idx_checklist_item_images_created_at
  ON checklist_item_images (created_at DESC);

-- 5. RLS
ALTER TABLE checklist_item_images ENABLE ROW LEVEL SECURITY;

-- Pattern 1: superuser e dev — acesso total
DROP POLICY IF EXISTS "superuser_dev_checklist_item_images_full" ON checklist_item_images;
CREATE POLICY "superuser_dev_checklist_item_images_full" ON checklist_item_images
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- Pattern 2: adm — CRUD na propria empresa
DROP POLICY IF EXISTS "adm_checklist_item_images_company" ON checklist_item_images;
CREATE POLICY "adm_checklist_item_images_company" ON checklist_item_images
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- Pattern 3: auditor SELECT via execucao pai (EXISTS subquery)
DROP POLICY IF EXISTS "auditor_checklist_item_images_select" ON checklist_item_images;
CREATE POLICY "auditor_checklist_item_images_select" ON checklist_item_images
  FOR SELECT
  USING (
    get_my_role() = 'auditor'
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_item_images.execution_id
        AND e.created_by = auth.uid()
    )
  );

-- Pattern 3: auditor INSERT (apenas proprias imagens em propria execucao)
DROP POLICY IF EXISTS "auditor_checklist_item_images_insert" ON checklist_item_images;
CREATE POLICY "auditor_checklist_item_images_insert" ON checklist_item_images
  FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_item_images.execution_id
        AND e.created_by = auth.uid()
    )
  );

-- Pattern 3: auditor DELETE (apenas suas proprias imagens)
DROP POLICY IF EXISTS "auditor_checklist_item_images_delete" ON checklist_item_images;
CREATE POLICY "auditor_checklist_item_images_delete" ON checklist_item_images
  FOR DELETE
  USING (
    get_my_role() = 'auditor'
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_item_images.execution_id
        AND e.created_by = auth.uid()
    )
  );

-- 6. Storage bucket checklist-images (bucket privado, separado de audit-images)
-- Insere apenas se ainda nao existir — idempotente
INSERT INTO storage.buckets (id, name, public)
VALUES ('checklist-images', 'checklist-images', false)
ON CONFLICT (id) DO NOTHING;

-- 7. Storage RLS: upload autenticado restrito ao proprio company_id
-- O path segue o padrao: {companyId}/{executionId}/{itemId}/{uuid}.jpg
-- A policy verifica que o primeiro segmento do path corresponde ao company_id do usuario

-- Politica de INSERT (upload) no Storage
DROP POLICY IF EXISTS "authenticated_upload_checklist_images" ON storage.objects;
CREATE POLICY "authenticated_upload_checklist_images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'checklist-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- Politica de SELECT (leitura para signed URL) no Storage
DROP POLICY IF EXISTS "authenticated_read_checklist_images" ON storage.objects;
CREATE POLICY "authenticated_read_checklist_images" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'checklist-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- Politica de DELETE no Storage
DROP POLICY IF EXISTS "authenticated_delete_checklist_images" ON storage.objects;
CREATE POLICY "authenticated_delete_checklist_images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'checklist-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- 8. Recarregar schema do PostgREST (sempre ultima linha)
NOTIFY pgrst, 'reload schema';
