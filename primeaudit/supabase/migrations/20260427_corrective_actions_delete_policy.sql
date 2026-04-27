-- Idempotente: policy de DELETE para auditor excluir apenas acoes que criou
DROP POLICY IF EXISTS "auditor_corrective_actions_delete" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_delete" ON corrective_actions
  FOR DELETE
  USING (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );
NOTIFY pgrst, 'reload schema';
