-- Migração idempotente: novos status para ações corretivas
-- Novo fluxo: aberta → em_analise → finalizada / reaberta → em_analise
-- Quando auditoria cancelada: cascade cancela ações vinculadas

-- 1. Ampliar CHECK constraint para incluir novos status
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_status_check;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_status_check
  CHECK (status IN (
    'aberta',
    'em_andamento',    -- legado (backward compat)
    'em_avaliacao',    -- legado (backward compat)
    'aprovada',        -- legado (backward compat)
    'rejeitada',       -- legado (backward compat)
    'em_analise',      -- novo: responsável respondeu, aguardando análise
    'finalizada',      -- novo: auditor/adm finalizou
    'reaberta',        -- novo: auditor/adm rejeitou, responsável pode reenviar
    'cancelada'
  ));

-- 2. Migrar registros legados para novos status
UPDATE corrective_actions SET status = 'em_analise'  WHERE status = 'em_avaliacao';
UPDATE corrective_actions SET status = 'finalizada'  WHERE status = 'aprovada';

NOTIFY pgrst, 'reload schema';
