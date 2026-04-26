-- =============================================================================
-- Migracao: tabela corrective_actions e RLS
-- Data: 2026-04-25
-- Idempotente: pode ser executado multiplas vezes sem erro.
-- =============================================================================

-- 1. Tabela base (somente id na criacao — colunas adicionadas com ADD COLUMN IF NOT EXISTS)
CREATE TABLE IF NOT EXISTS corrective_actions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

-- 2. Colunas (idempotentes)
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS audit_id            UUID NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS template_item_id    UUID NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS title               TEXT NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS description         TEXT;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS responsible_user_id UUID NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS due_date            DATE NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS status              TEXT NOT NULL DEFAULT 'aberta';
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS company_id          UUID NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS created_by          UUID NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 3. Foreign keys (drop + add para idempotencia — padrao de 20260406_create_audits.sql)
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_audit_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_audit_id_fkey
  FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_template_item_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_template_item_id_fkey
  FOREIGN KEY (template_item_id) REFERENCES template_items(id) ON DELETE RESTRICT;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_responsible_user_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_responsible_user_id_fkey
  FOREIGN KEY (responsible_user_id) REFERENCES profiles(id) ON DELETE RESTRICT;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_company_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_created_by_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE RESTRICT;

-- 4. CHECK constraint de status (drop + add para idempotencia)
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_status_check;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_status_check
  CHECK (status IN ('aberta','em_andamento','em_avaliacao','aprovada','rejeitada','cancelada'));

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_corrective_actions_company_id     ON corrective_actions (company_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_status         ON corrective_actions (status);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_responsible    ON corrective_actions (responsible_user_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_audit_id       ON corrective_actions (audit_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_created_at     ON corrective_actions (created_at DESC);

-- 6. RLS
ALTER TABLE corrective_actions ENABLE ROW LEVEL SECURITY;

-- superuser e dev: acesso total
DROP POLICY IF EXISTS "superuser_dev_corrective_actions_full" ON corrective_actions;
CREATE POLICY "superuser_dev_corrective_actions_full" ON corrective_actions
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: CRUD na propria empresa
DROP POLICY IF EXISTS "adm_corrective_actions_company" ON corrective_actions;
CREATE POLICY "adm_corrective_actions_company" ON corrective_actions
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- auditor: SELECT na propria empresa
DROP POLICY IF EXISTS "auditor_corrective_actions_select" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_select" ON corrective_actions
  FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

-- auditor: INSERT na propria empresa (apenas proprias acoes)
DROP POLICY IF EXISTS "auditor_corrective_actions_insert" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_insert" ON corrective_actions
  FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );

-- auditor: UPDATE na propria empresa (transicoes de status)
DROP POLICY IF EXISTS "auditor_corrective_actions_update" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_update" ON corrective_actions
  FOR UPDATE
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'auditor' AND company_id = get_my_company_id());

-- 7. Recarregar schema do PostgREST (sempre ultima linha)
NOTIFY pgrst, 'reload schema';
