-- ============================================================
-- PrimeAudit – Seed de Templates Padrão de Auditoria
-- Gerado em: 2026-04-01
-- Descrição: Cria templates globais para todos os tipos de
--            auditoria existentes no banco. Idempotente.
-- Execução: Supabase Dashboard → SQL Editor → Run
-- ============================================================

DO $$
DECLARE
  -- IDs dos tipos de auditoria (globais, já existentes no banco)
  TYPE_5S         CONSTANT UUID := '8fb30874-cb34-473e-8cb1-62c5410cc809';
  TYPE_COMPLIANCE CONSTANT UUID := 'aca5c3fc-b27c-4db4-b69e-8dd39c4a228e';
  TYPE_FORNECEDOR CONSTANT UUID := 'ff334170-46d0-4b29-bb0e-a6342e046d07';
  TYPE_LOGISTICA  CONSTANT UUID := 'ca265fa8-c944-4bce-9a72-944044acc0bd';
  TYPE_LPA        CONSTANT UUID := '237b3f48-e1e6-4b3d-9413-6faed3ca9c75';
  TYPE_MEIO_AMB   CONSTANT UUID := '3788d97a-f922-4a3d-aa7e-912bc3ad0147';
  TYPE_PROCESSO   CONSTANT UUID := 'd50263c1-fd20-4b6b-9d85-9ca087ada97e';
  TYPE_QUALIDADE  CONSTANT UUID := 'aa8a75cc-825f-4b21-a0fe-61b1f03bc7a2';
  TYPE_RH         CONSTANT UUID := 'b7d8a8ee-0041-44bd-a458-2fa349e8da09';
  TYPE_SEGURANCA  CONSTANT UUID := '921a38d7-3a82-4033-b167-a1924af5926c';

  tmpl UUID;
  sec1 UUID; sec2 UUID; sec3 UUID; sec4 UUID; sec5 UUID;
BEGIN

  ----------------------------------------------------------------
  -- 1. 5S / ORGANIZAÇÃO
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = '5S Completo' AND type_id = TYPE_5S) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_5S, NULL, '5S Completo',
       'Auditoria abrangente dos cinco sensos: Utilização, Ordenação, Limpeza, Padronização e Disciplina.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Seiri – Utilização', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Há materiais desnecessários no posto de trabalho?', 'Verificar itens sem uso nas últimas 2 semanas.', 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Ferramentas danificadas ou obsoletas estão sendo mantidas na área?', 'Equipamentos fora de uso devem ser etiquetados e removidos.', 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Documentos ou registros obsoletos foram descartados corretamente?', NULL, 'ok_nok', true, 1, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Itens pessoais estão armazenados em local adequado e separado da área de trabalho?', NULL, 'ok_nok', false, 1, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A área está livre de equipamentos danificados sem identificação ou etiqueta de status?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Seiton – Ordenação', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Todos os itens possuem local definido, identificado e demarcado?', 'Verificar etiquetas, fitas de demarcação e identificação de armários.', 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os itens de uso frequente estão acessíveis e armazenados próximos ao ponto de uso?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Existe demarcação visual (fitas no piso, etiquetas) para organizar o espaço?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As ferramentas estão organizadas e de fácil localização (painel, caixas)?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O layout do posto segue o padrão definido pelo gestor da área?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Seiso – Limpeza', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O posto de trabalho está limpo e sem sujeira, pó ou resíduos acumulados?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As máquinas e equipamentos estão limpos e livres de vazamentos de óleo ou fluidos?', 'Verificar bandejas coletoras, mangueiras e conexões.', 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A limpeza é realizada conforme o plano definido (responsável, frequência, método)?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os materiais de limpeza estão disponíveis, limpos e armazenados corretamente?', NULL, 'ok_nok', false, 1, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Seiketsu – Padronização', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'Existem instruções visuais (fotos padrão, cartazes) disponíveis e atualizadas?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os padrões de organização e limpeza estão documentados e de fácil acesso?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os colaboradores conhecem e sabem explicar os padrões 5S do seu posto?', 'Perguntar a um ou dois colaboradores aleatoriamente.', 'yes_no', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os EPIs necessários estão identificados, disponíveis e em bom estado no posto?', NULL, 'ok_nok', true, 2, 3, NULL);

    sec5 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec5, tmpl, 'Shitsuke – Disciplina', 4);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec5, 'Os colaboradores seguem os padrões 5S de forma espontânea?', 'Observar sem avisar previamente.', 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec5, 'As melhorias implementadas nas auditorias anteriores estão sendo mantidas?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec5, 'Foi realizada auditoria 5S no período anterior conforme a frequência estabelecida?', NULL, 'yes_no', true, 1, 2, NULL),
      (gen_random_uuid(), tmpl, sec5, 'As não conformidades da última auditoria foram corrigidas no prazo acordado?', NULL, 'ok_nok', true, 3, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria de Limpeza e Organização' AND type_id = TYPE_5S) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_5S, NULL, 'Auditoria de Limpeza e Organização',
       'Avaliação focada nas condições de limpeza, organização e identificação visual da área produtiva.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Condições do Ambiente', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O piso está limpo, sem resíduos, manchas ou líquidos derramados?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A iluminação da área está adequada e todas as lâmpadas funcionando?', NULL, 'ok_nok', true, 1, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As vias de circulação estão livres, demarcadas e sem obstruções?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O odor do ambiente é normal, sem indícios de vazamento de gases ou produtos químicos?', 'Em caso de odor anormal, acionar o responsável de segurança imediatamente.', 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As paredes e divisórias estão limpas e sem danos visíveis?', NULL, 'ok_nok', false, 1, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Organização de Materiais e Ferramentas', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Materiais de produção estão organizados, identificados e em seus locais definidos?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Ferramentas e dispositivos estão guardados nos locais corretos após o uso?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Estoques intermediários (WIP) estão devidamente identificados e limitados?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Materiais bloqueados não estão misturados com materiais aprovados?', 'Verificar etiquetas de status (verde = aprovado, vermelho = bloqueado).', 'ok_nok', true, 3, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Limpeza de Equipamentos e Instalações', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'As máquinas e equipamentos estão limpos externamente?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Bancadas de trabalho estão limpas e sem acúmulo de peças, ferramentas ou resíduos?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os coletores de resíduos (lixeiras) estão identificados, íntegros e com saco?', NULL, 'ok_nok', true, 1, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O plano de limpeza está afixado e sendo seguido (evidência de registros)?', NULL, 'ok_nok', true, 2, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Sinalização e Identificação Visual', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'As demarcações de piso (corredores, áreas de estoque) estão íntegras e visíveis?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os locais de armazenamento estão identificados com etiquetas ou cartazes?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'As saídas de emergência e extintores estão sinalizados e desobstruídos?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Qual é o nível geral de organização visual da área?', NULL, 'scale_1_5', true, 2, 3, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 2. COMPLIANCE / NORMAS
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'ISO 9001:2015 – Requisitos do SGQ' AND type_id = TYPE_COMPLIANCE) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_COMPLIANCE, NULL, 'ISO 9001:2015 – Requisitos do SGQ',
       'Auditoria interna baseada nos requisitos da norma ISO 9001:2015 para Sistemas de Gestão da Qualidade.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Contexto e Liderança (Seções 4 e 5)', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'A organização identificou questões internas/externas relevantes para o SGQ (4.1)?', 'Verificar atas de análise crítica ou documentos de contexto organizacional.', 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As partes interessadas e seus requisitos foram identificados e documentados (4.2)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O escopo do SGQ está documentado, disponível e comunicado (4.3)?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A Alta Direção demonstra comprometimento com o SGQ (5.1)?', 'Verificar participação em análises críticas e assinatura de políticas.', 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A Política da Qualidade está documentada, comunicada e disponível (5.2)?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Planejamento e Gestão de Riscos (Seção 6)', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Riscos e oportunidades foram identificados e tratados (6.1)?', 'Verificar matriz de riscos ou FMEAs.', 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os objetivos da qualidade são mensuráveis, monitorados e comunicados (6.2)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Existe planejamento para alcançar os objetivos com responsáveis e prazos?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O planejamento de mudanças considera riscos antes da implementação (6.3)?', NULL, 'ok_nok', false, 2, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Suporte – Recursos, Competências e Comunicação (Seção 7)', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Os recursos necessários para o SGQ estão determinados e disponíveis (7.1)?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As competências para cargos que afetam a qualidade estão definidas (7.2)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Colaboradores são conscientizados sobre a Política da Qualidade (7.3)?', 'Verificar registros de treinamento e conscientização.', 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A informação documentada exigida está disponível, legível e controlada (7.5)?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A comunicação interna/externa sobre o SGQ é gerenciada (7.4)?', NULL, 'ok_nok', false, 1, 4, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Operação e Controle de Processos (Seção 8)', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'Os processos operacionais estão planejados, controlados e documentados (8.1)?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os requisitos do cliente são analisados criticamente antes da aceitação (8.2)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os processos de fornecedores externos são controlados (8.4)?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Saídas não conformes são identificadas, controladas e tratadas (8.7)?', NULL, 'ok_nok', true, 3, 3, NULL);

    sec5 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec5, tmpl, 'Avaliação de Desempenho e Melhoria (Seções 9 e 10)', 4);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec5, 'O monitoramento e medição dos processos estão sendo realizados (9.1)?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec5, 'Auditorias internas são realizadas conforme programa definido (9.2)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec5, 'A Análise Crítica pela Direção é realizada com as entradas exigidas (9.3)?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec5, 'Não conformidades são tratadas com ações corretivas e verificação de eficácia (10.2)?', NULL, 'ok_nok', true, 3, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria de Procedimentos Internos' AND type_id = TYPE_COMPLIANCE) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_COMPLIANCE, NULL, 'Auditoria de Procedimentos Internos',
       'Verifica se os procedimentos internos estão disponíveis, atualizados e sendo seguidos nas atividades da área.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Disponibilidade e Atualização dos Documentos', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Os procedimentos relevantes para a área estão disponíveis no ponto de uso?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os documentos estão na versão mais recente (verificar revisão e data)?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Documentos obsoletos foram removidos da área de trabalho?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os procedimentos possuem responsável definido para revisão e aprovação?', NULL, 'ok_nok', true, 1, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Qual a periodicidade de revisão dos documentos desta área?', NULL, 'selection', false, 1, 4, ARRAY['Anual', 'Semestral', 'Trimestral', 'Sob demanda', 'Sem periodicidade definida']);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Conformidade na Execução', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Os colaboradores executam as atividades conforme os procedimentos estabelecidos?', 'Observar a execução e comparar com o procedimento.', 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os colaboradores conhecem e sabem onde localizar os procedimentos do seu posto?', 'Questionar ao menos dois colaboradores.', 'yes_no', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os desvios dos procedimentos são identificados e registrados?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As instruções especiais (alertas, pontos críticos) são conhecidas pelo operador?', NULL, 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Percentual estimado de conformidade com os procedimentos nesta área:', NULL, 'percentage', true, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Registros e Evidências', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Os registros exigidos pelos procedimentos estão sendo preenchidos corretamente?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os registros estão legíveis, sem rasuras e devidamente assinados?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O arquivamento dos registros respeita o prazo de retenção definido?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Existe rastreabilidade dos registros às atividades executadas?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Observações adicionais sobre os procedimentos desta área:', NULL, 'text', false, 1, 4, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 3. FORNECEDORES
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria de Sistema do Fornecedor' AND type_id = TYPE_FORNECEDOR) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_FORNECEDOR, NULL, 'Auditoria de Sistema do Fornecedor',
       'Avalia o sistema de gestão da qualidade, controle de processo e capacidade produtiva do fornecedor.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Sistema de Qualidade e Certificações', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O fornecedor possui certificação ISO 9001 ou equivalente válida?', NULL, 'yes_no', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O fornecedor possui documentação do SGQ (Manual da Qualidade ou equivalente)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Existem procedimentos documentados para os processos críticos de fabricação?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O fornecedor realiza auditorias internas com regularidade?', 'Solicitar evidências do programa de auditoria.', 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O fornecedor possui processo estruturado de análise crítica pela direção?', NULL, 'yes_no', false, 1, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Controle de Processo e Produto', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Os parâmetros de processo são monitorados e registrados?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Existem dispositivos de controle (poka-yokes, gabaritos) para garantir a qualidade?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os instrumentos de medição estão calibrados e com identificação de validade?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Existem planos de controle (Control Plans) para os produtos fornecidos?', NULL, 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O CEP é utilizado em características críticas de processo?', NULL, 'yes_no', false, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Gestão de Não Conformidades', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O fornecedor possui processo documentado para tratamento de não conformidades?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As não conformidades internas são registradas e tratadas com ações corretivas?', 'Verificar registros recentes de NCIs.', 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Existe controle efetivo de produtos não conformes (quarentena, identificação)?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O fornecedor atende reclamações do cliente dentro do prazo estabelecido (8D)?', NULL, 'ok_nok', true, 3, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Infraestrutura e Capacidade', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'A infraestrutura (máquinas, instalações) está em bom estado de conservação?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Existe programa de manutenção preventiva com registros e evidências?', NULL, 'yes_no', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A capacidade produtiva do fornecedor atende ao volume demandado?', NULL, 'yes_no', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Avaliação geral do fornecedor (1=reprovado, 5=excelente):', NULL, 'scale_1_5', true, 3, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria de Qualidade do Fornecedor' AND type_id = TYPE_FORNECEDOR) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_FORNECEDOR, NULL, 'Auditoria de Qualidade do Fornecedor',
       'Verifica controle de qualidade dos produtos, rastreabilidade, embalagem e processos de expedição do fornecedor.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Controle de Recebimento e Qualidade', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Existe inspeção de recebimento de matéria-prima com critérios definidos?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O critério de aceitação e rejeição no recebimento está documentado?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os registros de inspeção de recebimento estão disponíveis e completos?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A inspeção final do produto segue os critérios de aceitação definidos pelo cliente?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O nível de qualidade PPM do fornecedor está dentro do acordado?', NULL, 'yes_no', true, 3, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Rastreabilidade e Identificação', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Todos os produtos/lotes estão identificados desde a matéria-prima até a expedição?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'É possível rastrear um produto acabado até o lote de matéria-prima utilizado?', NULL, 'yes_no', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As etiquetas contêm informações mínimas (parte, lote, data)?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Qual o nível de rastreabilidade do fornecedor?', NULL, 'selection', false, 1, 3, ARRAY['Totalmente digital (ERP/MES)', 'Misto (digital + papel)', 'Manual (papel)', 'Sem rastreabilidade formal']);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Embalagem e Transporte', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'A embalagem está de acordo com as especificações técnicas e de proteção do produto?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A quantidade por embalagem está conforme o acordado?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As embalagens são manuseadas de forma a evitar danos ao produto?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os documentos de expedição (NF, certificados) estão presentes e corretos?', NULL, 'ok_nok', true, 2, 3, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 4. LOGÍSTICA
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Armazenagem e Expedição' AND type_id = TYPE_LOGISTICA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_LOGISTICA, NULL, 'Armazenagem e Expedição',
       'Avalia as condições de armazenamento, controle de entrada de materiais e processo de expedição.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Condições de Armazenagem', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O armazém está organizado com endereçamento de posições definido e identificado?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As condições ambientais (temperatura, umidade) são adequadas para os produtos armazenados?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os itens estão armazenados de forma segura, sem risco de queda ou dano?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Materiais bloqueados/quarentena estão segregados fisicamente dos aprovados?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As vias de circulação internas estão livres e sinalizadas?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Controle de Entrada de Materiais', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Existe processo de inspeção/conferência no recebimento de materiais?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os materiais recebidos são registrados no sistema antes de serem armazenados?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Divergências entre NF e mercadoria recebida são registradas e tratadas?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O tempo de recebimento e entrada no estoque está dentro do prazo aceitável?', NULL, 'yes_no', false, 1, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Expedição e Documentação Fiscal', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O processo de separação (picking) é realizado conforme os documentos de expedição?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A conferência final antes da expedição é realizada e registrada?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As embalagens utilizadas na expedição protegem adequadamente o produto?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os documentos fiscais (NF-e, DANFE, romaneio) são emitidos corretamente?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Existe rastreabilidade dos pedidos expedidos (número do pedido, data, destinatário)?', NULL, 'ok_nok', true, 2, 4, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Controle de Inventário e FIFO' AND type_id = TYPE_LOGISTICA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_LOGISTICA, NULL, 'Controle de Inventário e FIFO',
       'Verifica a acuracidade do inventário, aplicação do método FIFO/FEFO e rastreabilidade dos itens em estoque.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Identificação e Rastreabilidade dos Itens', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Todos os itens em estoque possuem identificação visível (etiqueta, código, lote)?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A data de entrada ou validade está indicada nas embalagens/posições?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O status dos materiais (aprovado, bloqueado, em inspeção) está indicado?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Itens com validade vencida foram identificados e segregados?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O sistema de endereçamento permite localizar qualquer item em menos de 2 minutos?', NULL, 'yes_no', false, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Aplicação do FIFO / FEFO', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'O método FIFO (Primeiro a Entrar, Primeiro a Sair) está sendo aplicado nas saídas?', 'Verificar últimas movimentações no sistema e confrontar com posição física.', 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Para produtos com validade, o FEFO está sendo respeitado?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O layout das prateleiras/posições facilita a aplicação do FIFO?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Existem materiais com lotes antigos não movimentados há mais de 90 dias?', NULL, 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os operadores conhecem e aplicam corretamente o FIFO/FEFO?', NULL, 'yes_no', true, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Acuracidade e Contagem do Inventário', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'A acuracidade do inventário (%) está acima da meta estabelecida?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Contagens cíclicas são realizadas conforme o plano e com a frequência definida?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As divergências identificadas nas contagens são investigadas e corrigidas?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Percentual atual de acuracidade do inventário desta área:', NULL, 'percentage', true, 3, 3, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 5. LPA (LAYERED PROCESS AUDIT)
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'LPA Nível 1 – Operador' AND type_id = TYPE_LPA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_LPA, NULL, 'LPA Nível 1 – Operador',
       'Auditoria em camadas realizada pelo operador ou líder de célula. Foco em qualidade do produto, condições do posto e segurança básica.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Qualidade do Produto no Processo', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O operador realiza a autoinspeção conforme a instrução de trabalho?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os dispositivos de controle (gabarito, poka-yoke) estão funcionando corretamente?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A primeira peça do turno foi verificada e aprovada antes de iniciar a produção?', NULL, 'yes_no', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Não há peças não conformes misturadas com peças aprovadas?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O operador sabe o que fazer em caso de peça suspeita ou não conforme?', NULL, 'yes_no', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Condições do Posto de Trabalho', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'A instrução de trabalho (IT) está disponível e na revisão atual?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As ferramentas e dispositivos necessários estão disponíveis e em bom estado?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O posto está limpo e organizado conforme o padrão 5S?', NULL, 'ok_nok', true, 1, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os parâmetros de processo estão dentro dos limites especificados?', 'Verificar registros ou display do equipamento.', 'ok_nok', true, 3, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Segurança Individual', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O operador está utilizando os EPIs exigidos para o posto de trabalho?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As proteções e dispositivos de segurança das máquinas estão instalados e ativos?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O operador conhece o procedimento de emergência (parada de máquina, evacuação)?', NULL, 'yes_no', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A área está livre de riscos evidentes (derramamentos, fios expostos, obstáculos)?', NULL, 'ok_nok', true, 3, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'LPA Nível 2 – Líder' AND type_id = TYPE_LPA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_LPA, NULL, 'LPA Nível 2 – Líder',
       'Auditoria em camadas realizada pelo líder de equipe. Verifica LPA Nível 1 e aspectos gerenciais de processo e equipe.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Verificação do LPA Nível 1', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O LPA Nível 1 foi realizado conforme a frequência estabelecida?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os registros do LPA Nível 1 estão preenchidos corretamente?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As não conformidades do LPA N1 receberam ação imediata?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O operador demonstra conhecimento adequado dos itens do LPA N1?', NULL, 'yes_no', true, 2, 3, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Qualidade, Processo e Dispositivos', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Os planos de controle estão sendo seguidos corretamente?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As características especiais do produto (CC/SC) estão sendo monitoradas?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os poka-yokes foram verificados no início do turno?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O índice de retrabalho/sucata da área está dentro da meta?', NULL, 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Existem desvios de processo não registrados ou não tratados?', NULL, 'ok_nok', true, 3, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Gestão de Equipe e Treinamentos', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Todos os colaboradores do turno estão treinados e qualificados para suas funções?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A matriz de habilidades da equipe está atualizada?', NULL, 'ok_nok', false, 1, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O briefing do turno (passagem de informações) foi realizado?', NULL, 'yes_no', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As ausências planejadas têm cobertura para garantir a produção?', NULL, 'ok_nok', false, 1, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Manutenção e Equipamentos', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'As ordens de manutenção preventiva estão sendo executadas no prazo?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Equipamentos com parada imprevista foram registrados e analisados (causa raiz)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'As manutenções autônomas (limpeza, inspeção, lubrificação) estão sendo realizadas?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Avaliação da eficiência global dos equipamentos (OEE) da área:', NULL, 'scale_1_5', false, 2, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'LPA Nível 3 – Supervisão' AND type_id = TYPE_LPA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_LPA, NULL, 'LPA Nível 3 – Supervisão',
       'Auditoria em camadas pela supervisão/gerência. Foco em indicadores, eficácia do sistema LPA e gestão do fluxo produtivo.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Verificação do LPA Nível 2', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O LPA Nível 2 foi realizado conforme a frequência definida?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As não conformidades abertas no LPA N2 têm responsável e prazo de resolução?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A taxa de fechamento de NCs dos LPAs N1 e N2 está adequada?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O sistema LPA está funcionando como planejado em toda a área?', NULL, 'ok_nok', true, 2, 3, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Indicadores e Ações do Processo', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Os indicadores de qualidade (PPM, rejeições) estão dentro das metas?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os indicadores de produtividade (OEE, eficiência) estão dentro das metas?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As ações corretivas de não conformidades recorrentes foram eficazes?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As reclamações de clientes desta área foram analisadas e tratadas?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os projetos de melhoria contínua estão com progresso satisfatório?', NULL, 'ok_nok', false, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Conformidade do Fluxo de Produção', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O fluxo de valor está atualizado e refletindo a realidade do processo?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os balanceamentos de linha estão adequados à demanda atual do cliente?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os estoques em processo (WIP) estão dentro dos limites definidos?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A programação de produção está sendo cumprida dentro do desvio aceitável?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Avaliação geral do nível de maturidade do sistema LPA nesta área:', NULL, 'scale_1_5', true, 3, 4, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 6. MEIO AMBIENTE
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Gestão de Resíduos Sólidos' AND type_id = TYPE_MEIO_AMB) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_MEIO_AMB, NULL, 'Gestão de Resíduos Sólidos',
       'Verifica a correta segregação, identificação, armazenamento e destinação final de resíduos sólidos conforme a PNRS.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Segregação e Identificação na Fonte', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Os resíduos estão sendo segregados na fonte conforme o PGRS?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os coletores estão identificados com a cor correta (CONAMA 275)?', 'Azul=papel, verde=vidro, amarelo=metal, vermelho=plástico, laranja=perigoso, cinza=não reciclável.', 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os resíduos perigosos (classe I) estão identificados com símbolo de risco e GHS?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os colaboradores foram treinados para a correta segregação de resíduos?', NULL, 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Não há contaminação cruzada entre tipos de resíduos nos coletores?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Armazenamento Temporário', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'O abrigo de armazenamento temporário de resíduos está identificado e organizado?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O prazo máximo de armazenamento de resíduos perigosos (1 ano) está sendo respeitado?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'A área está impermeabilizada com sistema de contenção de vazamentos?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O acesso ao abrigo de resíduos é restrito e controlado?', NULL, 'ok_nok', false, 1, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Destinação Final e Documentação', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Os resíduos são enviados a destinadores licenciados pelo órgão ambiental competente?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os Manifestos de Transporte de Resíduos (MTR) estão sendo emitidos e arquivados?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os Certificados de Destinação Final (CDF) estão disponíveis e arquivados?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O inventário de resíduos (tipo, quantidade, destinador) está atualizado?', NULL, 'ok_nok', true, 2, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Controle Ambiental – Emissões e Consumo' AND type_id = TYPE_MEIO_AMB) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_MEIO_AMB, NULL, 'Controle Ambiental – Emissões e Consumo',
       'Avalia o controle de emissões atmosféricas, efluentes líquidos, consumo de recursos naturais e gestão de produtos químicos.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Emissões Atmosféricas', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'As fontes de emissão estão identificadas no inventário de emissões da empresa?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As medições de emissões estão sendo realizadas na periodicidade legal?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os filtros/lavadores de gases estão em bom estado de funcionamento?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os resultados das medições estão dentro dos padrões de emissão estabelecidos?', NULL, 'ok_nok', true, 3, 3, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Efluentes Líquidos', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'O tratamento de efluentes está em operação e dentro dos parâmetros?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os laudos de análise de efluentes estão dentro do prazo e conformes?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Não há descarte irregular de efluentes ou produtos líquidos no ambiente?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O sistema de contenção de vazamentos (canaletas, caixas separadoras) está operacional?', NULL, 'ok_nok', true, 2, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Consumo de Água e Energia', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O consumo de água é monitorado mensalmente com metas estabelecidas?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O consumo de energia elétrica é monitorado e comparado às metas de redução?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Existem programas ativos de conservação de água e energia?', NULL, 'yes_no', false, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Vazamentos de água nas instalações foram identificados e corrigidos?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Avaliação do desempenho ambiental geral da área (1=muito ruim, 5=excelente):', NULL, 'scale_1_5', true, 2, 4, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Armazenamento de Produtos Químicos', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'Os produtos químicos estão armazenados conforme as FISPQs?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'As FISPQs estão disponíveis no local de armazenamento e de uso?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Produtos incompatíveis estão segregados fisicamente (ácidos x bases, oxidantes x inflamáveis)?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'O estoque de produtos químicos é controlado por inventário atualizado?', NULL, 'ok_nok', true, 2, 3, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 7. PROCESSO
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Trabalho Padronizado (TP)' AND type_id = TYPE_PROCESSO) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_PROCESSO, NULL, 'Trabalho Padronizado (TP)',
       'Verifica se as instruções de trabalho são seguidas, os padrões de processo são cumpridos e os colaboradores estão qualificados.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Documentação e Instrução de Trabalho', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'A Instrução de Trabalho (IT) está disponível no ponto de uso e na versão atual?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A IT contém fotos/imagens claras das etapas críticas do processo?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os parâmetros críticos do processo (limites de controle) estão descritos na IT?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O folheto de trabalho padronizado (Takt Time, WIP padrão, sequência) está atualizado?', NULL, 'ok_nok', false, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Existe plano de aprovação para alterações nas ITs (controle de mudanças)?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Conformidade na Execução do Processo', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'O operador executa as etapas na sequência definida pela IT?', 'Observar a execução por pelo menos 5 minutos e comparar com a IT.', 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O tempo de ciclo real está próximo ao tempo de ciclo padrão definido?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os torques, medidas e parâmetros de processo são verificados conforme especificado?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O WIP está dentro dos limites definidos pelo padrão?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Percentual de conformidade da execução com o trabalho padronizado:', NULL, 'percentage', true, 3, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Controle e Dispositivos de Processo', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Os instrumentos e dispositivos de controle estão funcionando corretamente?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os poka-yokes e sistemas à prova de erro foram testados no início do turno?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'As anormalidades de processo são reportadas imediatamente ao líder?', NULL, 'yes_no', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O sistema de gestão visual (andons, quadros de produção) está atualizado?', NULL, 'ok_nok', false, 1, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Treinamento e Qualificação no Padrão', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'O operador foi treinado e está qualificado para este processo (TWI/OJT)?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'O registro de treinamento na IT está atualizado com assinatura do operador e instrutor?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Em caso de novo operador, foi realizado acompanhamento com operador experiente?', NULL, 'yes_no', false, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'O operador consegue explicar as etapas críticas e os pontos de controle do processo?', 'Verificar verbalmente com o operador.', 'yes_no', true, 2, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Setup de Máquina / SMED' AND type_id = TYPE_PROCESSO) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_PROCESSO, NULL, 'Setup de Máquina / SMED',
       'Avalia o processo de setup de máquinas, aplicação do SMED (redução de tempo de troca) e conformidade da liberação pós-setup.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Preparação e Documentação Pré-Setup', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O kit de setup (ferramentas, gabaritos, documentos) foi preparado antes da parada?', 'Verificar se atividades externas foram realizadas com a máquina ainda produzindo.', 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A ordem de produção e especificações do próximo produto estão disponíveis?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O procedimento de setup está disponível e na versão atual?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As atividades externas do setup foram separadas corretamente das internas?', NULL, 'ok_nok', false, 2, 3, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Execução do Setup', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'O operador segue a sequência de setup definida no procedimento?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As regulagens e parâmetros são ajustados conforme a tabela de setup?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Ferramentas e gabaritos estão em boas condições e no tamanho correto?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Todos os torques e fixações foram realizados conforme as especificações?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O tempo de setup está sendo cronometrado e registrado?', NULL, 'yes_no', true, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Verificação e Liberação Pós-Setup', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'A peça inicial (first piece) foi produzida e aprovada antes de liberar a produção?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A aprovação do first piece foi registrada com assinatura e horário?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os parâmetros do processo após o setup estão dentro dos limites de controle?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A área foi limpa e organizada após o setup?', NULL, 'ok_nok', true, 1, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O material do produto anterior foi removido ou segregado corretamente?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Registro e Análise de Tempo', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'O tempo total de setup foi registrado no sistema ou formulário padrão?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'O tempo de setup está dentro da meta estabelecida (SMED)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Desvios e dificuldades do setup foram registrados para análise de melhoria?', NULL, 'ok_nok', false, 1, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Avaliação do setup realizado (1=muito ruim, 5=excelente):', NULL, 'scale_1_5', true, 2, 3, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 8. QUALIDADE
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Qualidade de Produto Final' AND type_id = TYPE_QUALIDADE) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_QUALIDADE, NULL, 'Qualidade de Produto Final',
       'Inspeção do produto acabado contemplando verificação visual, dimensional, rastreabilidade e conformidade para expedição.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Inspeção Visual e Acabamento', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O produto está isento de defeitos visuais (trincas, rebarbas, amassados, riscos)?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O acabamento superficial está dentro do especificado no desenho ou padrão visual?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A cor, textura e aspecto geral estão conformes com a amostra padrão aprovada?', NULL, 'ok_nok', false, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A montagem e encaixe de componentes estão corretos e sem folgas excessivas?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O produto está limpo, sem óleo, pó ou resíduos de processo?', NULL, 'ok_nok', true, 1, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Controle Dimensional e Tolerâncias', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'As dimensões críticas foram medidas com instrumento adequado e calibrado?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os resultados das medições estão dentro das tolerâncias especificadas no desenho?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As características especiais (CC/SC) foram todas inspecionadas e conformes?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Percentual de conformidade dimensional do lote inspecionado:', NULL, 'percentage', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os registros das medições foram preenchidos corretamente no formulário de inspeção?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Rastreabilidade e Documentação', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O produto possui etiqueta com número de peça, lote e data de fabricação?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'É possível rastrear o produto até as matérias-primas e componentes utilizados?', NULL, 'yes_no', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O certificado de conformidade ou relatório de inspeção foi emitido e está correto?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os registros de inspeção estão arquivados pelo prazo mínimo exigido?', NULL, 'ok_nok', false, 1, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Embalagem e Liberação para Expedição', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'A embalagem está de acordo com as especificações técnicas de proteção do produto?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A quantidade por embalagem está correta conforme o padrão de embalagem?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A etiqueta da embalagem possui todas as informações obrigatórias (código, quantidade, lote)?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A liberação formal do lote foi dada pelo responsável de qualidade?', NULL, 'ok_nok', true, 3, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria de Processo de Qualidade' AND type_id = TYPE_QUALIDADE) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_QUALIDADE, NULL, 'Auditoria de Processo de Qualidade',
       'Avalia controles de processo, calibração de instrumentos, poka-yokes e eficácia do tratamento de não conformidades.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Controle Estatístico do Processo (CEP)', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O CEP está sendo aplicado nas características críticas de qualidade do processo?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As cartas de controle estão atualizadas e os operadores sabem interpretá-las?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O índice Cpk está acima de 1,33 para características especiais?', 'Verificar últimos cálculos de Cpk disponíveis.', 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Pontos fora de controle são imediatamente investigados e documentados?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os dados do CEP são coletados conforme o plano de controle (frequência e amostragem)?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Calibração e Instrumentos de Medição', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Todos os instrumentos possuem etiqueta de calibração com validade vigente?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O plano de calibração está sendo seguido com as periodicidades definidas?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Instrumentos com calibração vencida foram retirados de uso e identificados?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O MSA (Análise dos Sistemas de Medição) foi realizado para instrumentos críticos?', NULL, 'yes_no', false, 2, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Poka-Yoke e Sistemas de Controle', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Todos os poka-yokes e dispositivos à prova de erro foram verificados e estão funcionais?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O plano de verificação dos poka-yokes está sendo seguido (frequência, responsável)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Existe registro das verificações dos dispositivos de controle?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Em caso de falha de um poka-yoke, o processo é parado até a restauração?', NULL, 'yes_no', true, 3, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Tratamento de Não Conformidades', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'As não conformidades internas são registradas no sistema de qualidade?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A análise de causa raiz (5 Porquês, Ishikawa ou 8D) é realizada para NCs reincidentes?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'As ações corretivas têm responsável e prazo definidos e são monitoradas?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A eficácia das ações corretivas é verificada após o prazo definido?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A área de quarentena para produtos não conformes está identificada e controlada?', NULL, 'ok_nok', true, 2, 4, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'First Piece Check (Peça Inicial)' AND type_id = TYPE_QUALIDADE) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_QUALIDADE, NULL, 'First Piece Check (Peça Inicial)',
       'Verificação completa da primeira peça produzida após setup ou retomada para garantir conformidade antes da produção em série.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Verificação Dimensional do First Piece', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Todas as cotas críticas foram medidas e estão dentro das tolerâncias do desenho?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As características especiais (CC/SC) foram todas verificadas e estão conformes?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os resultados foram registrados no formulário de First Piece?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os instrumentos utilizados estão calibrados e com validade vigente?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Percentual de características dimensionais conformes na First Piece:', NULL, 'percentage', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Verificação Visual e Funcional', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'A peça está isenta de defeitos visuais (rebarbas, trincas, amassados, riscos)?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O acabamento superficial está de acordo com a especificação ou amostra padrão?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'A peça foi submetida ao teste funcional definido no plano de controle?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'A peça passou no gabarito de verificação (go/no-go) conforme aplicável?', NULL, 'ok_nok', false, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'A identificação da peça (número, lote, data) está correta?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Aprovação e Documentação', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'A First Piece foi aprovada com assinatura do responsável de qualidade?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O horário de aprovação do first piece foi registrado?', NULL, 'ok_nok', true, 1, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A produção em série só iniciou após a aprovação formal do first piece?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Em caso de first piece reprovada, foi realizado ajuste e nova verificação?', 'Se aprovada na primeira tentativa, registrar como N/A.', 'ok_nok', false, 2, 3, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 9. RECURSOS HUMANOS
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria de Treinamento e Competências' AND type_id = TYPE_RH) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_RH, NULL, 'Auditoria de Treinamento e Competências',
       'Verifica o planejamento, execução e eficácia dos treinamentos e a atualização da matriz de competências da equipe.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Planejamento e Matriz de Treinamento', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Existe plano anual de treinamento aprovado para a área?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A matriz de treinamento / LNT está atualizada?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As competências mínimas para cada cargo estão definidas e documentadas?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O índice de realização do plano de treinamento está acima da meta?', NULL, 'yes_no', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Percentual de execução do plano de treinamento no período:', NULL, 'percentage', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Execução e Frequência dos Treinamentos', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Os treinamentos obrigatórios (NR-12, CIPA, etc.) estão em dia para todos os colaboradores?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As reciclagens e renovações de certificações estão dentro do prazo?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os treinamentos são ministrados por instrutores qualificados e credenciados?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'A metodologia dos treinamentos é adequada ao público-alvo?', NULL, 'ok_nok', false, 1, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Avaliação de Eficácia e Resultados', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Existe avaliação de aprendizagem após os treinamentos (prova, prática)?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A eficácia dos treinamentos é verificada por mudanças de comportamento ou indicadores?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Treinamentos com nota abaixo do mínimo tiveram reforço ou retreinamento?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os resultados das avaliações são comunicados aos colaboradores e gestores?', NULL, 'yes_no', false, 1, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Certificações e Documentação', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'Os registros de presença e certificados estão arquivados corretamente?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Os documentos de treinamento estão arquivados pelo prazo legal (mínimo 5 anos)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'As habilitações e certificações especiais (NRs, operador de empilhadeira) estão vigentes?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A documentação de treinamento está disponível para auditorias externas?', NULL, 'ok_nok', true, 2, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Integração de Novos Colaboradores' AND type_id = TYPE_RH) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_RH, NULL, 'Integração de Novos Colaboradores',
       'Verifica o cumprimento do processo de onboarding: documentação admissional, apresentação da empresa e treinamentos obrigatórios iniciais.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Documentação Admissional', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'O contrato de trabalho foi assinado e entregue ao colaborador?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O ASO (Atestado de Saúde Ocupacional) admissional foi realizado e está arquivado?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O registro na CTPS e cadastro no eSocial foram realizados corretamente?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O colaborador recebeu os EPIs com assinatura do recibo de entrega?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O código de conduta e política da empresa foram apresentados e assinados?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Apresentação e Integração Inicial', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'O colaborador recebeu apresentação institucional (história, valores, estrutura)?', NULL, 'ok_nok', true, 1, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Foi realizado tour pelas instalações mostrando áreas e saídas de emergência?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'O colaborador foi apresentado à equipe e ao seu responsável direto?', NULL, 'ok_nok', true, 1, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As metas, indicadores e expectativas do cargo foram comunicados ao novo colaborador?', NULL, 'ok_nok', true, 2, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Treinamentos Obrigatórios de Início', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'O treinamento de integração de segurança (SIPAT/CIPA) foi realizado?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O treinamento de segurança específico para a função foi concluído antes de assumir o posto?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O treinamento na instrução de trabalho (IT) foi realizado com tutor designado?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O colaborador foi avaliado quanto ao entendimento das tarefas antes de trabalhar sozinho?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O período de acompanhamento (buddy/tutor) foi respeitado conforme o padrão?', NULL, 'ok_nok', true, 2, 4, NULL);
  END IF;

  ----------------------------------------------------------------
  -- 10. SEGURANÇA (EHS)
  ----------------------------------------------------------------

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Condições Gerais de Segurança' AND type_id = TYPE_SEGURANCA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_SEGURANCA, NULL, 'Condições Gerais de Segurança',
       'Avaliação ampla das condições físicas de segurança: sinalização, instalações, prevenção de incêndios e plano de emergência.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Sinalização, Rotas e Emergência', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'As rotas de fuga estão sinalizadas, iluminadas e desobstruídas?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As saídas de emergência estão identificadas, funcionando e sem bloqueios?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'A sinalização de segurança (advertências, proibições, obrigações) está visível e legível?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os pontos de encontro em evacuação estão sinalizados e conhecidos pela equipe?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'As demarcações de piso estão íntegras diferenciando corredores, áreas e riscos?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Instalações e Equipamentos', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'As instalações elétricas estão em bom estado (sem fios expostos, quadros fechados, aterramento)?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As proteções e guardas das máquinas estão instaladas e em bom estado?', 'Verificar proteções de partes móveis, painéis e dispositivos de parada de emergência.', 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os botões de parada de emergência estão funcionando, desobstruídos e sinalizados?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As escadas, plataformas e passarelas possuem corrimão e piso antiderrapante?', NULL, 'ok_nok', true, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Equipamentos com TAG de bloqueio (LOTO) não estão sendo operados sem autorização?', NULL, 'ok_nok', true, 3, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Prevenção e Combate a Incêndios', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Os extintores estão nos locais definidos, dentro do prazo de validade e desobstruídos?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os hidrantes e mangueiras de incêndio estão em bom estado e acessíveis?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Não há materiais inflamáveis armazenados incorretamente na área?', NULL, 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os detectores de fumaça e sprinklers (quando aplicável) estão funcionais?', NULL, 'ok_nok', false, 2, 3, NULL);

    sec4 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec4, tmpl, 'Plano de Emergência e Primeiros Socorros', 3);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec4, 'Os colaboradores conhecem os procedimentos de emergência da área?', 'Questionar dois colaboradores sobre o que fazer em caso de incêndio ou acidente.', 'yes_no', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec4, 'O simulacro de evacuação foi realizado dentro do prazo máximo (anual)?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec4, 'A caixa de primeiros socorros está completa, dentro do prazo e identificada?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec4, 'Existe colaborador treinado em primeiros socorros por turno disponível na área?', NULL, 'yes_no', true, 2, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Uso e Controle de EPIs' AND type_id = TYPE_SEGURANCA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_SEGURANCA, NULL, 'Uso e Controle de EPIs',
       'Verifica disponibilidade, condição, uso correto e gestão documental dos Equipamentos de Proteção Individual (EPIs).', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Disponibilidade e Estado dos EPIs', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Todos os EPIs exigidos para o posto estão disponíveis e em quantidade suficiente?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os EPIs estão em bom estado de conservação, sem avarias, rasgos ou deformações?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os EPIs possuem CA (Certificado de Aprovação) válido do MTE/MPS?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os EPIs estão dentro do prazo de validade indicado pelo fabricante?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'O estoque de EPIs é suficiente para reposição imediata?', NULL, 'ok_nok', true, 2, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Uso Correto pelos Colaboradores', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Todos os colaboradores estão utilizando os EPIs obrigatórios para suas atividades?', 'Verificar uso de capacete, óculos, luvas, protetor auricular e calçado de segurança.', 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os EPIs estão sendo usados corretamente (forma de colocação e ajuste)?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os colaboradores foram treinados sobre o uso correto dos EPIs?', NULL, 'yes_no', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Há colaboradores utilizando EPIs danificados ou inadequados ao risco?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Visitantes e prestadores de serviço estão utilizando os EPIs obrigatórios na área?', NULL, 'ok_nok', false, 2, 4, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Gestão e Controle de EPIs', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'Existe ficha de EPI individual atualizada para cada colaborador com assinatura de recebimento?', NULL, 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O processo de descarte e substituição de EPIs deteriorados está funcionando?', NULL, 'ok_nok', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'O laudo técnico de periculosidade/insalubridade está atualizado embasando os EPIs exigidos?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os EPIs estão sendo armazenados adequadamente quando não em uso?', NULL, 'ok_nok', false, 1, 3, NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM audit_templates WHERE name = 'Auditoria Comportamental de Segurança (BBS)' AND type_id = TYPE_SEGURANCA) THEN
    tmpl := gen_random_uuid();
    INSERT INTO audit_templates (id, type_id, company_id, name, description, active) VALUES
      (tmpl, TYPE_SEGURANCA, NULL, 'Auditoria Comportamental de Segurança (BBS)',
       'Observação de comportamentos seguros e inseguros (Behavior-Based Safety). Foco em atitudes, comunicação de riscos e cultura de segurança.', true);

    sec1 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec1, tmpl, 'Comportamentos e Atitudes Observadas', 0);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec1, 'Os colaboradores adotam posturas ergonômicas corretas durante as atividades?', 'Observar levantamento de cargas, posicionamento no posto e movimentos repetitivos.', 'ok_nok', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Não há "atalhos" ou desvios de procedimentos de segurança observados?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Os colaboradores mantêm as áreas sem riscos criados por eles mesmos?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Há evidências de comunicação proativa entre colegas sobre riscos identificados?', 'Perguntar se algum colaborador reportou risco recentemente.', 'yes_no', false, 2, 3, NULL),
      (gen_random_uuid(), tmpl, sec1, 'Avaliação geral dos comportamentos de segurança observados (1=muito inseguro, 5=exemplar):', NULL, 'scale_1_5', true, 3, 4, NULL);

    sec2 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec2, tmpl, 'Comunicação e Reporte de Riscos', 1);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec2, 'Os colaboradores conhecem o canal/processo para reportar riscos e condições inseguras?', NULL, 'yes_no', true, 2, 0, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Registros de relatos de perigo (hazard reports) foram realizados na área no período?', NULL, 'yes_no', true, 2, 1, NULL),
      (gen_random_uuid(), tmpl, sec2, 'Os acidentes e quase-acidentes (near-misses) são reportados sem medo de represálias?', 'Verificar registros de near-miss e questionar um colaborador sobre o processo.', 'ok_nok', true, 3, 2, NULL),
      (gen_random_uuid(), tmpl, sec2, 'As lideranças promovem diálogos de segurança (DDS) com regularidade?', NULL, 'ok_nok', true, 2, 3, NULL);

    sec3 := gen_random_uuid();
    INSERT INTO template_sections (id, template_id, name, order_index) VALUES (sec3, tmpl, 'Cumprimento de Normas e Procedimentos de Segurança', 2);
    INSERT INTO template_items (id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options) VALUES
      (gen_random_uuid(), tmpl, sec3, 'As Permissões de Trabalho (PT) estão sendo emitidas para trabalhos de risco?', NULL, 'ok_nok', true, 3, 0, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Os procedimentos de bloqueio e etiquetagem (LOTO) são seguidos integralmente?', NULL, 'ok_nok', true, 3, 1, NULL),
      (gen_random_uuid(), tmpl, sec3, 'A APR (Análise Preliminar de Riscos) é realizada antes de atividades não rotineiras?', NULL, 'ok_nok', true, 2, 2, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Trabalhos em altura (acima de 2m) são realizados somente com EPI específico e PT emitida?', NULL, 'ok_nok', true, 3, 3, NULL),
      (gen_random_uuid(), tmpl, sec3, 'Percentual de conformidade com os procedimentos de segurança nesta área:', NULL, 'percentage', true, 3, 4, NULL);
  END IF;

END $$;
