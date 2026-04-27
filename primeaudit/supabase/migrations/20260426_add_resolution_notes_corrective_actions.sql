-- Idempotente: adiciona coluna resolution_notes à corrective_actions
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS resolution_notes TEXT;
NOTIFY pgrst, 'reload schema';
