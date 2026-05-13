-- Fix: adicionar policies de Storage para superuser/dev no bucket audit-images
--
-- Problema: get_my_company_id() retorna NULL para superuser/dev (sem company_id fixo
-- no perfil). A policy authenticated_* usa (foldername)[1] = get_my_company_id()::text,
-- que avalia NULL = <valor> = NULL (falso) → 403 para superuser/dev.
--
-- Fix: policies separadas para superuser/dev que verificam apenas o bucket_id,
-- espelhando o padrão já aplicado em 20260511 para checklist-images.

-- INSERT (upload)
DROP POLICY IF EXISTS "superuser_dev_upload_audit_images" ON storage.objects;
CREATE POLICY "superuser_dev_upload_audit_images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'audit-images'
    AND get_my_role() IN ('superuser', 'dev')
  );

-- SELECT (leitura para signed URL)
DROP POLICY IF EXISTS "superuser_dev_read_audit_images" ON storage.objects;
CREATE POLICY "superuser_dev_read_audit_images" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'audit-images'
    AND get_my_role() IN ('superuser', 'dev')
  );

-- DELETE
DROP POLICY IF EXISTS "superuser_dev_delete_audit_images" ON storage.objects;
CREATE POLICY "superuser_dev_delete_audit_images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'audit-images'
    AND get_my_role() IN ('superuser', 'dev')
  );

NOTIFY pgrst, 'reload schema';
