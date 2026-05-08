-- Seed: templates Bosch/MUNK importados de Checklist_Consolidado_BOSCH_MUNK.xlsx
-- company_id: e37e95e4-d263-4c10-aa40-b70ae2df75d7
-- NOTA: visíveis apenas para superuser/dev pela RLS atual.
-- Para tornar visíveis a adm/auditor da empresa, definir created_by com UUID do admin.

-- Template: Veículos Corporativos 1
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_templates WHERE id = 'b94f4805-2f08-58a0-95d0-924801c59eab') THEN
    INSERT INTO checklist_templates (id, name, category, description, is_padrao, company_id, created_by)
    VALUES ('b94f4805-2f08-58a0-95d0-924801c59eab', 'Veículos Corporativos 1', 'transportadora', 'Checklist de vistoria: Veículos Corporativos 1', false, 'e37e95e4-d263-4c10-aa40-b70ae2df75d7', NULL);
  END IF;
END $$;

-- Items de Veículos Corporativos 1
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_template_items WHERE template_id = 'b94f4805-2f08-58a0-95d0-924801c59eab' LIMIT 1) THEN
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('ce774916-ba1c-514b-b822-d5f17e24db49', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Motorista', 'text', 0);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('c51ce6dc-f359-5116-9356-a4b10062bcfa', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'CNH', 'text', 1);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('cf60a834-9650-54e4-85f3-0d906c7d2a15', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Veículo', 'text', 2);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('ff5d25e3-8955-54e1-ad19-3c333be115ab', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Modelo', 'text', 3);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1cd0cc24-c5cf-5050-989b-63d154a7af93', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Placa', 'text', 4);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('f9b40848-a09e-5f11-b3ab-760c5fbf5e27', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Data de Saída', 'date', 5);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('c4b0fe54-88fb-596d-82d8-26b2b7de4ebe', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Hora de Saída', 'text', 6);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a7610e67-b46a-5107-a5da-c502dfc95429', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Data de Retorno', 'date', 7);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e551eb3d-ef69-5672-abd0-cacb40508aa0', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Hora de Retorno', 'text', 8);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('bc1c26a7-0f84-5faf-bf27-3fee3ea12c10', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Origem', 'text', 9);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('4e0f6374-865e-5b4f-9cd3-a06d858ed817', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Destino', 'text', 10);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('98e7dc5d-7ab4-527e-861c-989490fb5427', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Pneus', 'yes_no', 11);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('453b4675-3243-56b9-bf1c-b528a245cf17', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Nível do Óleo', 'yes_no', 12);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('7732115f-1c00-5464-aa2d-81e341bdd3c1', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Faróis', 'yes_no', 13);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('4abc7e7d-6f90-59f5-913a-9d17ac2a5a47', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Pisca', 'yes_no', 14);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('aaad4d1e-6d5f-5df5-bd03-90618050721d', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Lanternas', 'yes_no', 15);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('499c1b56-4134-555b-9970-57a2ff5f7161', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Luz de Ré', 'yes_no', 16);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('88eabb59-fb1c-547c-8a8f-59be0c76cb48', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Amassados', 'yes_no', 17);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6afac1a6-00e7-58ad-8514-da3fa7bf65dd', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Riscos', 'yes_no', 18);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('56a61ada-48fb-55b1-a664-8628725ce711', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Painel', 'yes_no', 19);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('5704ce91-b5cb-5648-8a24-c0d857aaee90', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Bancos', 'yes_no', 20);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('80ef0acf-8f6f-551c-a21d-70c56d4ba7e4', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Limpeza Externa', 'yes_no', 21);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('b4512c49-d1c0-5938-8ebd-7fd3b78ea4f3', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Limpeza Interna', 'yes_no', 22);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('2b0c3fbb-1fab-5a79-b8bf-ca4295f47c54', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Avarias na Imagem (diagrama)', 'photo', 23);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('437da52a-3622-5c6c-b632-b478b5a4b2b8', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Observações', 'text', 24);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('49db16f4-4961-57d5-9123-937afaf8b7b8', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Veículo está perfeito?', 'yes_no', 25);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('98478ab3-76fd-534e-9f9d-6383b56f4dc6', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Documento do veículo e CNH em dia?', 'yes_no', 26);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('64d7b9a1-8328-5df4-a102-b802592a25d0', 'b94f4805-2f08-58a0-95d0-924801c59eab', 'Assinatura do Motorista Responsável', 'photo', 27);
  END IF;
END $$;

-- Template: VANS
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_templates WHERE id = '7def77e2-4206-5b9b-b0cc-838d54ce377f') THEN
    INSERT INTO checklist_templates (id, name, category, description, is_padrao, company_id, created_by)
    VALUES ('7def77e2-4206-5b9b-b0cc-838d54ce377f', 'VANS', 'transportadora', 'Checklist de vistoria: VANS', false, 'e37e95e4-d263-4c10-aa40-b70ae2df75d7', NULL);
  END IF;
END $$;

-- Items de VANS
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_template_items WHERE template_id = '7def77e2-4206-5b9b-b0cc-838d54ce377f' LIMIT 1) THEN
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('60f5bcce-fbac-584c-96a0-81134022c133', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Motorista', 'text', 0);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('8c162c80-8e00-5c23-86af-be6be8d113b6', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'CNH', 'text', 1);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('5eba459c-5135-5ffb-b114-f68953eb6acc', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Veículo', 'text', 2);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e6e8a14f-e8e7-5fea-a35e-0f3f8b8d67e4', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Modelo', 'text', 3);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('914639a8-2ac2-5802-94fc-b1cd61d9c040', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Placa', 'text', 4);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('f6f16562-b1f2-5bd9-af95-bc54542e6503', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Data de Saída', 'date', 5);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('97622ceb-1c9f-5fcc-b89f-5cb783d9927d', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Hora de Saída', 'text', 6);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a7ba5f95-82d7-5933-81cb-f1d8a0c937da', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Data de Retorno', 'date', 7);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('bb67c817-7297-5062-8e80-906f4032be43', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Hora de Retorno', 'text', 8);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('56db4e07-c33f-5247-a9be-959703badd01', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Origem', 'text', 9);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('8354010a-5af3-5c0d-ac69-99ba58d95e5f', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Destino', 'text', 10);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('4e550e94-31e2-512b-bf0d-8737367791c2', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Pneus', 'yes_no', 11);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('43676879-5954-56b5-8d4a-bb361e5e667a', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Nível do Óleo', 'yes_no', 12);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6e8d0c1d-5a16-53bf-b463-31ac927afc02', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Faróis', 'yes_no', 13);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('554ca1b1-3b57-564c-8e6a-81a4e7068354', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Pisca', 'yes_no', 14);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('37513426-cbb2-504c-8d73-f60ebc77f5c9', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Lanternas', 'yes_no', 15);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('dd342deb-ba9e-5ee9-924e-89217fb4dbb6', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Luz de Ré', 'yes_no', 16);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1f67982a-e64e-5133-a301-b4575c7a9281', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Amassados', 'yes_no', 17);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1853a39d-a65c-5c7e-9774-e19508541832', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Riscos', 'yes_no', 18);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a25e1328-0dfa-56cd-b5b6-75ee26129f48', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Painel', 'yes_no', 19);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('bcf0c5a5-c460-5bb9-89c2-1bdcd877e77b', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Bancos', 'yes_no', 20);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1ba007af-906d-521d-bf77-94b89163a2ab', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Limpeza Externa', 'yes_no', 21);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('bc13fafe-3f73-51b0-a054-063a32951bfb', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Limpeza Interna', 'yes_no', 22);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('5a94e654-87dd-50bd-8ddc-9eac399ce934', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Porta Passageiros', 'yes_no', 23);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('d0ff6066-e77e-5aed-8817-f67b7a033326', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Banco de Passageiros', 'yes_no', 24);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('439aea34-4c94-5057-93de-3bbc62db2664', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Televisão', 'yes_no', 25);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6c44a992-4671-58dc-8fdb-fb65f715c2a7', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Avarias na Imagem (diagrama)', 'photo', 26);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('8172a826-2313-5dc4-b7ad-cfe231ad3e15', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Observações', 'text', 27);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('03e54b1d-eada-510d-a5ec-dfbd9889ad38', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Veículo está perfeito?', 'yes_no', 28);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('4ed72361-5cb1-5008-9ef2-fcc60bda8a53', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Documento do veículo e CNH em dia?', 'yes_no', 29);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('f31af61f-10c9-5e04-84fc-f87f22308f75', '7def77e2-4206-5b9b-b0cc-838d54ce377f', 'Assinatura do Motorista Responsável', 'photo', 30);
  END IF;
END $$;

-- Template: Veículos Corporativos
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_templates WHERE id = '213dd64d-cad0-5a0e-8838-79455aedcc79') THEN
    INSERT INTO checklist_templates (id, name, category, description, is_padrao, company_id, created_by)
    VALUES ('213dd64d-cad0-5a0e-8838-79455aedcc79', 'Veículos Corporativos', 'transportadora', 'Checklist de vistoria: Veículos Corporativos', false, 'e37e95e4-d263-4c10-aa40-b70ae2df75d7', NULL);
  END IF;
END $$;

-- Items de Veículos Corporativos
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_template_items WHERE template_id = '213dd64d-cad0-5a0e-8838-79455aedcc79' LIMIT 1) THEN
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('289b529b-3f5e-5bfc-8de5-6b7717c25558', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Motorista', 'text', 0);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('14cdafd1-304c-515d-a937-98f66ec7a4de', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'CNH', 'text', 1);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('bf837dee-ddf3-54e4-8d6d-b53aee668568', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Veículo', 'text', 2);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('cd5d549d-b1b8-596e-8ef2-ece701478399', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Modelo', 'text', 3);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6d960b5d-cbca-5c64-a24c-2d21bde27f9c', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Placa', 'text', 4);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e373eeb9-1e10-5bfd-9046-2a982a468b9d', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Data de Saída', 'date', 5);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('618a02c5-a698-5402-824b-32d5a0ef50e3', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Hora de Saída', 'text', 6);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('56d17993-ac8c-5acf-9a27-655292218a20', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Data de Retorno', 'date', 7);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6108e363-d6e4-5d14-839d-303d2a4ba895', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Hora de Retorno', 'text', 8);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('0af538ce-9ad7-5876-b346-c84fb97bf0e9', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Origem', 'text', 9);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('3b57f797-dad8-51ef-b037-d7f5b3543f7d', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Destino', 'text', 10);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('c497d14a-5da5-5ae6-bfe2-664fb685ff1c', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Pneus', 'yes_no', 11);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('7d4fdfbb-1689-5707-934b-746f8c4b811e', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Nível do Óleo', 'yes_no', 12);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('f1673bd3-b2fd-5d46-8e58-a18c20e4c3b5', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Faróis', 'yes_no', 13);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('f075a117-71b6-58e3-ac00-ceb7611d0d24', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Pisca', 'yes_no', 14);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('cd4d34ca-1acc-5a90-baee-6f3c1178e339', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Lanternas', 'yes_no', 15);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('399363d7-b312-512d-bf6f-1ee7410a61b8', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Luz de Ré', 'yes_no', 16);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1ad02559-68b8-53e6-9811-13f1c4310da6', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Lataria', 'yes_no', 17);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('94ab655e-1082-551c-bd14-11a4b06598ed', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Pintura', 'yes_no', 18);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('9ccc43c7-0088-5fd4-a8ec-a3c362aac4dc', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Painel', 'yes_no', 19);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('7dd35e33-6db5-515f-86eb-4ce01994fe81', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Bancos', 'yes_no', 20);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('2f7aa054-7593-54c1-94a9-3952404a83d3', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Limpeza Externa', 'yes_no', 21);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('35192f63-1a87-578b-9ea8-28c0e074d152', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Limpeza Interna', 'yes_no', 22);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('75fa88f8-b660-533f-a940-3635b68dc109', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Caçamba', 'yes_no', 23);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('65243754-877d-5956-b8ef-619b63604c68', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Cap. Caçamba', 'yes_no', 24);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('9df69590-01de-5cbb-87b1-31d1bb3ce272', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Retrovisor', 'yes_no', 25);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e20b3e07-fd24-5a7e-a10e-eb8b666ba474', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Avarias na Imagem (diagrama)', 'photo', 26);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('4955dd00-995c-5c5e-9945-c1121c51dab1', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Observações', 'text', 27);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6682e399-f04b-5818-b2cc-4a3871f11db1', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Veículo está perfeito?', 'yes_no', 28);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('dd506b60-1245-5e3d-953c-f696e19f56f8', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Documento do veículo e CNH em dia?', 'yes_no', 29);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('0235d87c-0e7c-51e5-98b7-e1ab5d06f36b', '213dd64d-cad0-5a0e-8838-79455aedcc79', 'Assinatura do Motorista Responsável', 'photo', 30);
  END IF;
END $$;

-- Template: Caminhão / Munck
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_templates WHERE id = 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8') THEN
    INSERT INTO checklist_templates (id, name, category, description, is_padrao, company_id, created_by)
    VALUES ('c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Caminhão / Munck', 'transportadora', 'Checklist de vistoria: Caminhão / Munck', false, 'e37e95e4-d263-4c10-aa40-b70ae2df75d7', NULL);
  END IF;
END $$;

-- Items de Caminhão / Munck
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM checklist_template_items WHERE template_id = 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8' LIMIT 1) THEN
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('827c1e48-f219-54c7-ad08-d528c152d947', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Motorista', 'text', 0);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('896206e2-b06c-5bcf-bf53-51a2240ec776', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'CNH', 'text', 1);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('301ec97b-5738-58e4-8efe-49c73ded0966', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Veículo', 'text', 2);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('2c7610c0-82e7-55ca-aa0e-8145d6e7e76a', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Modelo', 'text', 3);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('d446ad8b-9aa8-5981-91fa-30ddef15b926', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Placa', 'text', 4);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('789eb815-69ca-5032-9aa4-755cb7888ca0', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Data da Saída', 'date', 5);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('3792a85e-dd1e-5c00-85f3-2f343c542245', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Data do Retorno', 'date', 6);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('daa17bdd-08ab-59ec-9b15-8f8f5528ff36', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Origem', 'text', 7);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('66c77192-3a51-500e-b0e3-0b5c599c82a3', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Destino', 'text', 8);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6254a681-070b-5df3-9c36-f3c0086b7394', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Pneus', 'yes_no', 9);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('95488f19-2b79-54af-b315-08e88ddfa87b', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Estepe', 'yes_no', 10);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('40066ba7-f475-5b13-8b0b-e21b8811beb4', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Rodas', 'yes_no', 11);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('54ca4d3a-90e1-550a-bc42-6c74dd0d4dbb', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Freio', 'yes_no', 12);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('ada5e6e0-bf93-55d5-bd1e-e2d95720296c', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Freio Estacionário', 'yes_no', 13);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1a6047db-b293-5be5-853d-d2a56cca0a46', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Farol', 'yes_no', 14);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('fb689311-e77c-5b0d-8bb6-67cb92386a4c', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Setas', 'yes_no', 15);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('ace46f80-d9bb-5e59-af0a-59a26db388a9', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Alerta', 'yes_no', 16);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('6285aa2d-59e2-5ced-9f44-e00519f6d5bd', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Luz de Ré', 'yes_no', 17);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a333b757-9b90-5f3d-a4d8-94a57ef6d90e', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Luz de Freio', 'yes_no', 18);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('56d2981a-e6cd-5646-ad91-13bfe08b3185', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Lanterna Traseira', 'yes_no', 19);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('cd51d55c-9d4e-58e7-99a0-b9f5d5312a83', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Alerta de Ré', 'yes_no', 20);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('88b6b38e-f782-507f-b807-11e1c0214865', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Direção Hidráulica', 'yes_no', 21);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('32cb26f3-4444-5a57-abb7-4dcbc53995ce', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Tacógrafo', 'yes_no', 22);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('78fa4a39-7378-58ce-9e77-22bfe945ada2', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Painel de Instrumentos', 'yes_no', 23);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('b0e6f41a-1857-5813-a7ff-5e7564d406a6', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Bancos', 'yes_no', 24);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1f87ba36-6470-5ec6-b5d6-36b18550525a', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Chave de Segurança', 'yes_no', 25);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('be58cb14-5aba-5172-a677-753d80ffeb54', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Triângulo', 'yes_no', 26);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e6e3ad7e-4ede-57c5-8164-d9349e9de744', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Extintor', 'yes_no', 27);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e3d40448-a40c-5c58-91c4-b492e381efad', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Bateria', 'yes_no', 28);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('89fe2c63-58ed-5e72-9073-50ab49d24746', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Carroceria', 'yes_no', 29);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('d31a307e-9873-50eb-96e5-2b58ed64aa96', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Assoalho', 'yes_no', 30);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('d65e6c21-a279-55b1-8560-07c95001aaa5', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Tampa Combustível', 'yes_no', 31);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('85fe136b-ab0f-533e-bebb-1c40ad70c734', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Escapamento', 'yes_no', 32);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('f4364a8c-309e-51e1-b4b4-1f985ad0534d', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Nível Óleo do Motor', 'yes_no', 33);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('4c3abb3d-128d-5152-9787-0f66b3f02358', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Água do Radiador', 'yes_no', 34);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('452bc3b0-e0ef-51b6-ab3c-495788ba0d0c', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Óleo de Freio', 'yes_no', 35);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('ccac848e-b4ff-55f8-8ac1-f94822acc9ea', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Limpeza Interna', 'yes_no', 36);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('dc14958d-efc4-56c3-8df2-f52c3c93b214', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Limpeza Externa', 'yes_no', 37);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a4e7bfdc-50ff-52bd-b816-c88f3892da41', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Vazamentos (MUNCK)', 'yes_no', 38);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a5eb3e26-9174-5dbc-b35d-94b6ca6a3516', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Condições das Mangueiras (MUNCK)', 'yes_no', 39);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('59f75eb1-3269-5609-b039-07634eb395a0', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Bomba Hidráulica (MUNCK)', 'yes_no', 40);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('2992d464-7eb1-58d8-a0fb-b45337a7d086', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Lança (MUNCK)', 'yes_no', 41);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('87694382-dd30-5bb3-af76-d115b4b8cbbf', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Moitão e Trava Guincho (MUNCK)', 'yes_no', 42);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('5c548f55-a820-56b1-bee8-f8574bbae1d1', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Pátolas (MUNCK)', 'yes_no', 43);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('fa6218a0-9027-5a90-83c2-349877807004', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Manetes de Comando (MUNCK)', 'yes_no', 44);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('cc9f1904-6784-5653-ad4e-96c7f06101b8', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Horímetro (MUNCK)', 'yes_no', 45);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('920af971-c357-5154-b206-ff48b270f851', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Óleo Hidráulico (MUNCK)', 'yes_no', 46);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('e00ea408-1cdd-5801-8d05-956aecdcdb67', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Cabos de Aço (MUNCK)', 'yes_no', 47);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('1b2827d3-a431-5944-89f5-3ca57e943772', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Cintas 4 mts. - 5 ton. (MUNCK)', 'yes_no', 48);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('82a6ec04-3238-5963-b192-7af5def75829', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Cintas 6 mts. - 5 ton. (MUNCK)', 'yes_no', 49);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('86ada6b3-17c9-566b-9f05-28012879ddf8', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Anilha 3/4 (MUNCK)', 'yes_no', 50);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('12a9bfc6-e87d-5e19-a8a5-f6a6ca449a82', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Anilha 1/4 (MUNCK)', 'yes_no', 51);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('a589f9a5-da9a-5373-8717-abb724394d5f', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Anilha 1 (MUNCK)', 'yes_no', 52);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('61e95102-5dac-54b8-b5c8-63e89f207afc', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', '12 Cinta e Catraca 5 ton. (MUNCK)', 'yes_no', 53);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('5a9fc523-1625-5d14-98d7-3259058e9959', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', '04 Cinta e Catraca 2 mts. 5 ton. (MUNCK)', 'yes_no', 54);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('465dcabc-f004-5560-8b30-7c79fc8b83e6', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Anotações para Manutenção', 'text', 55);
    INSERT INTO checklist_template_items (id, template_id, description, item_type, order_index)
    VALUES ('123adeda-c360-5d07-96f3-fe4ce245edb9', 'c8cbc66c-ea80-5c52-aca0-90058ef49ad8', 'Assinatura do Motorista Responsável', 'photo', 56);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';