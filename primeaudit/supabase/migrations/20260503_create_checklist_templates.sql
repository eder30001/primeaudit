-- =============================================================================
-- Migração: checklist_templates e checklist_template_items
-- Data: 2026-05-03
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- Tabelas novas; zero alterações em audit_templates / template_items.
-- =============================================================================


-- ----------------------------------------------------------------------------
-- 1. Tabela checklist_templates
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checklist_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS name        TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS category    TEXT        NOT NULL DEFAULT 'industrial';
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS is_padrao   BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS company_id  UUID;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_by  UUID;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW();


-- ----------------------------------------------------------------------------
-- 2. Constraints de checklist_templates
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_category_check;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_category_check
  CHECK (category IN ('industrial', 'transportadora'));

ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_company_id_fkey;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL;

ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_created_by_fkey;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;


-- ----------------------------------------------------------------------------
-- 3. Tabela checklist_template_items
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checklist_template_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
-- NOTA: template_id usa DEFAULT gen_random_uuid() apenas para satisfazer NOT NULL
-- durante ADD COLUMN IF NOT EXISTS em tabela potencialmente não-vazia (idempotência).
-- Todo row real fornecerá um template_id explícito.
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS template_id   UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS description   TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS item_type     TEXT        NOT NULL DEFAULT 'yes_no';
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS order_index   INTEGER     NOT NULL DEFAULT 0;
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW();


-- ----------------------------------------------------------------------------
-- 4. Constraints de checklist_template_items
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_template_items DROP CONSTRAINT IF EXISTS checklist_template_items_template_id_fkey;
ALTER TABLE checklist_template_items ADD CONSTRAINT checklist_template_items_template_id_fkey
  FOREIGN KEY (template_id) REFERENCES checklist_templates(id) ON DELETE CASCADE;

ALTER TABLE checklist_template_items DROP CONSTRAINT IF EXISTS checklist_template_items_item_type_check;
ALTER TABLE checklist_template_items ADD CONSTRAINT checklist_template_items_item_type_check
  CHECK (item_type IN ('yes_no', 'text', 'number', 'date', 'multiple_choice', 'photo'));


-- ----------------------------------------------------------------------------
-- 5. Índices
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_checklist_templates_category   ON checklist_templates (category);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_created_by ON checklist_templates (created_by);
CREATE INDEX IF NOT EXISTS idx_checklist_template_items_tmpl  ON checklist_template_items (template_id, order_index);


-- ----------------------------------------------------------------------------
-- 6. RLS para checklist_templates (Padrão 2 — is_padrao guard)
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_checklist_templates_full" ON checklist_templates;
CREATE POLICY "superuser_dev_checklist_templates_full" ON checklist_templates
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

DROP POLICY IF EXISTS "authenticated_checklist_templates_select" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_select" ON checklist_templates FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (is_padrao = true OR created_by = auth.uid())
  );

DROP POLICY IF EXISTS "authenticated_checklist_templates_insert" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_insert" ON checklist_templates FOR INSERT
  WITH CHECK (
    get_my_role() IS NOT NULL
    AND is_padrao = false
    AND created_by = auth.uid()
  );

DROP POLICY IF EXISTS "authenticated_checklist_templates_update" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_update" ON checklist_templates FOR UPDATE
  USING  (get_my_role() IS NOT NULL AND is_padrao = false AND created_by = auth.uid())
  WITH CHECK (get_my_role() IS NOT NULL AND is_padrao = false AND created_by = auth.uid());

DROP POLICY IF EXISTS "authenticated_checklist_templates_delete" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_delete" ON checklist_templates FOR DELETE
  USING (get_my_role() IS NOT NULL AND is_padrao = false AND created_by = auth.uid());


-- ----------------------------------------------------------------------------
-- 7. RLS para checklist_template_items (Padrão 3 — subquery via FK)
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_template_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_checklist_template_items_full" ON checklist_template_items;
CREATE POLICY "superuser_dev_checklist_template_items_full" ON checklist_template_items
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

DROP POLICY IF EXISTS "authenticated_checklist_template_items_select" ON checklist_template_items;
CREATE POLICY "authenticated_checklist_template_items_select" ON checklist_template_items FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND (t.is_padrao = true OR t.created_by = auth.uid())
    )
  );

DROP POLICY IF EXISTS "authenticated_checklist_template_items_write" ON checklist_template_items;
CREATE POLICY "authenticated_checklist_template_items_write" ON checklist_template_items
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND t.is_padrao = false
        AND t.created_by = auth.uid()
    )
  )
  WITH CHECK (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND t.is_padrao = false
        AND t.created_by = auth.uid()
    )
  );


-- =============================================================================
-- Seeds: 10 templates padrão (is_padrao = true, company_id = NULL, created_by = NULL)
-- Idempotente: ON CONFLICT (id) DO NOTHING garante re-execução segura.
-- =============================================================================

-- Seeds Industrial
INSERT INTO checklist_templates (id, name, category, description, is_padrao, company_id, created_by)
VALUES
  ('a1b2c3d4-0001-0001-0001-000000000001', 'Inspeção de EPI e Segurança do Trabalho', 'industrial',
   'Verifica conformidade do uso de EPIs e condições de segurança no ambiente de trabalho.', true, NULL, NULL),
  ('a1b2c3d4-0001-0001-0001-000000000002', 'Auditoria de 5S Industrial', 'industrial',
   'Avalia a aplicação dos 5 sensos: Seiri, Seiton, Seiso, Seiketsu e Shitsuke.', true, NULL, NULL),
  ('a1b2c3d4-0001-0001-0001-000000000003', 'Inspeção de Máquinas e Equipamentos', 'industrial',
   'Verifica estado de conservação, proteções e operacionalidade de máquinas.', true, NULL, NULL),
  ('a1b2c3d4-0001-0001-0001-000000000004', 'Checklist de Manutenção Preventiva', 'industrial',
   'Controle de atividades de manutenção preventiva em equipamentos críticos.', true, NULL, NULL),
  ('a1b2c3d4-0001-0001-0001-000000000005', 'Inspeção de Riscos Elétricos', 'industrial',
   'Avalia condições de instalações elétricas e conformidade com NR-10.', true, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- Seeds Transportadora
INSERT INTO checklist_templates (id, name, category, description, is_padrao, company_id, created_by)
VALUES
  ('b2c3d4e5-0002-0002-0002-000000000001', 'Vistoria de Veículo Leve', 'transportadora',
   'Inspeção pré-viagem de veículos leves: pneus, freios, fluidos e documentação.', true, NULL, NULL),
  ('b2c3d4e5-0002-0002-0002-000000000002', 'Vistoria de Veículo Pesado / Caminhão', 'transportadora',
   'Inspeção pré-viagem de caminhões e veículos pesados conforme CONTRAN.', true, NULL, NULL),
  ('b2c3d4e5-0002-0002-0002-000000000003', 'Checklist de Carregamento e Embalagem', 'transportadora',
   'Verifica correto acondicionamento, lacração e rotulagem de cargas.', true, NULL, NULL),
  ('b2c3d4e5-0002-0002-0002-000000000004', 'Inspeção de Motorista e Documentação', 'transportadora',
   'Confere habilitação, exame médico, tacógrafo e conformidade do motorista.', true, NULL, NULL),
  ('b2c3d4e5-0002-0002-0002-000000000005', 'Auditoria de Processo de Entrega', 'transportadora',
   'Avalia o processo completo de entrega: recebimento, conferência e assinatura.', true, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- Seed items para templates Industrial (~5 itens cada)
INSERT INTO checklist_template_items (template_id, description, item_type, order_index)
VALUES
  -- EPI e Segurança
  ('a1b2c3d4-0001-0001-0001-000000000001', 'Todos os colaboradores utilizam EPIs adequados à função?', 'yes_no', 0),
  ('a1b2c3d4-0001-0001-0001-000000000001', 'Os EPIs estão em bom estado de conservação?', 'yes_no', 1),
  ('a1b2c3d4-0001-0001-0001-000000000001', 'As saídas de emergência estão desobstruídas?', 'yes_no', 2),
  ('a1b2c3d4-0001-0001-0001-000000000001', 'Os extintores estão dentro do prazo de validade?', 'yes_no', 3),
  ('a1b2c3d4-0001-0001-0001-000000000001', 'Observações gerais de segurança', 'text', 4),
  -- 5S
  ('a1b2c3d4-0001-0001-0001-000000000002', 'Os materiais desnecessários foram descartados (Seiri)?', 'yes_no', 0),
  ('a1b2c3d4-0001-0001-0001-000000000002', 'Itens estão identificados e em locais definidos (Seiton)?', 'yes_no', 1),
  ('a1b2c3d4-0001-0001-0001-000000000002', 'O ambiente está limpo e sem resíduos (Seiso)?', 'yes_no', 2),
  ('a1b2c3d4-0001-0001-0001-000000000002', 'Os padrões definidos estão sendo seguidos (Seiketsu)?', 'yes_no', 3),
  ('a1b2c3d4-0001-0001-0001-000000000002', 'Nota geral de disciplina do setor (1-10)', 'number', 4),
  -- Máquinas
  ('a1b2c3d4-0001-0001-0001-000000000003', 'As proteções de segurança das máquinas estão instaladas?', 'yes_no', 0),
  ('a1b2c3d4-0001-0001-0001-000000000003', 'Existe sinalização de risco nas máquinas?', 'yes_no', 1),
  ('a1b2c3d4-0001-0001-0001-000000000003', 'As máquinas possuem botão de emergência funcionando?', 'yes_no', 2),
  ('a1b2c3d4-0001-0001-0001-000000000003', 'Há registro de manutenção atualizado?', 'yes_no', 3),
  ('a1b2c3d4-0001-0001-0001-000000000003', 'Descreva irregularidades encontradas', 'text', 4),
  -- Manutenção Preventiva
  ('a1b2c3d4-0001-0001-0001-000000000004', 'O plano de manutenção preventiva está atualizado?', 'yes_no', 0),
  ('a1b2c3d4-0001-0001-0001-000000000004', 'As últimas manutenções foram realizadas no prazo?', 'yes_no', 1),
  ('a1b2c3d4-0001-0001-0001-000000000004', 'Os lubrificantes utilizados estão dentro da especificação?', 'yes_no', 2),
  ('a1b2c3d4-0001-0001-0001-000000000004', 'Data da próxima manutenção programada', 'date', 3),
  ('a1b2c3d4-0001-0001-0001-000000000004', 'Observações do técnico responsável', 'text', 4),
  -- Riscos Elétricos
  ('a1b2c3d4-0001-0001-0001-000000000005', 'Quadros elétricos estão identificados e trancados?', 'yes_no', 0),
  ('a1b2c3d4-0001-0001-0001-000000000005', 'Os cabos elétricos estão protegidos e sem exposição?', 'yes_no', 1),
  ('a1b2c3d4-0001-0001-0001-000000000005', 'Há aterramento adequado nas instalações?', 'yes_no', 2),
  ('a1b2c3d4-0001-0001-0001-000000000005', 'Os colaboradores possuem treinamento NR-10 válido?', 'yes_no', 3),
  ('a1b2c3d4-0001-0001-0001-000000000005', 'Registro fotográfico de não conformidades', 'photo', 4)
ON CONFLICT DO NOTHING;

-- Seed items para templates Transportadora (~5 itens cada)
INSERT INTO checklist_template_items (template_id, description, item_type, order_index)
VALUES
  -- Veículo Leve
  ('b2c3d4e5-0002-0002-0002-000000000001', 'Pneus em bom estado (sem desgaste excessivo ou furos)?', 'yes_no', 0),
  ('b2c3d4e5-0002-0002-0002-000000000001', 'Freios funcionando corretamente?', 'yes_no', 1),
  ('b2c3d4e5-0002-0002-0002-000000000001', 'Nível de óleo e fluidos verificados?', 'yes_no', 2),
  ('b2c3d4e5-0002-0002-0002-000000000001', 'Documentação do veículo (CRLV, seguro) em dia?', 'yes_no', 3),
  ('b2c3d4e5-0002-0002-0002-000000000001', 'Observações sobre o estado geral do veículo', 'text', 4),
  -- Caminhão
  ('b2c3d4e5-0002-0002-0002-000000000002', 'Pneus (incluindo estepes) em condições adequadas?', 'yes_no', 0),
  ('b2c3d4e5-0002-0002-0002-000000000002', 'Sistema de freios (serviço e estacionamento) funcionando?', 'yes_no', 1),
  ('b2c3d4e5-0002-0002-0002-000000000002', 'Luzes e sinalização em funcionamento?', 'yes_no', 2),
  ('b2c3d4e5-0002-0002-0002-000000000002', 'Tacógrafo calibrado e funcionando?', 'yes_no', 3),
  ('b2c3d4e5-0002-0002-0002-000000000002', 'Número do lacre do tacógrafo', 'text', 4),
  -- Carregamento
  ('b2c3d4e5-0002-0002-0002-000000000003', 'A carga está corretamente identificada e rotulada?', 'yes_no', 0),
  ('b2c3d4e5-0002-0002-0002-000000000003', 'O acondicionamento impede deslocamento durante o transporte?', 'yes_no', 1),
  ('b2c3d4e5-0002-0002-0002-000000000003', 'O lacre de segurança foi aplicado corretamente?', 'yes_no', 2),
  ('b2c3d4e5-0002-0002-0002-000000000003', 'O peso da carga está dentro do limite da frota?', 'yes_no', 3),
  ('b2c3d4e5-0002-0002-0002-000000000003', 'Número do documento de transporte (CT-e / MDF-e)', 'text', 4),
  -- Motorista
  ('b2c3d4e5-0002-0002-0002-000000000004', 'CNH válida e compatível com a categoria do veículo?', 'yes_no', 0),
  ('b2c3d4e5-0002-0002-0002-000000000004', 'Exame médico ocupacional em dia?', 'yes_no', 1),
  ('b2c3d4e5-0002-0002-0002-000000000004', 'Motorista descansado (respeito à jornada e HS)?', 'yes_no', 2),
  ('b2c3d4e5-0002-0002-0002-000000000004', 'Treinamento de direção defensiva realizado no último ano?', 'yes_no', 3),
  ('b2c3d4e5-0002-0002-0002-000000000004', 'Data de vencimento do exame médico', 'date', 4),
  -- Entrega
  ('b2c3d4e5-0002-0002-0002-000000000005', 'O destinatário confirmou o recebimento?', 'yes_no', 0),
  ('b2c3d4e5-0002-0002-0002-000000000005', 'A quantidade entregue confere com o pedido?', 'yes_no', 1),
  ('b2c3d4e5-0002-0002-0002-000000000005', 'Houve avaria ou perda durante o transporte?', 'yes_no', 2),
  ('b2c3d4e5-0002-0002-0002-000000000005', 'Assinatura do recebedor coletada?', 'yes_no', 3),
  ('b2c3d4e5-0002-0002-0002-000000000005', 'Observações sobre a entrega', 'text', 4)
ON CONFLICT DO NOTHING;


-- ----------------------------------------------------------------------------
-- 8. Recarregar schema cache do PostgREST
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
