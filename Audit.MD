# PrimeAudit — Diário de Desenvolvimento

App Flutter para auditorias industriais com backend Supabase.

---

## 2026-04-06

### Fluxo completo de auditorias

#### Novos arquivos
| Arquivo | Descrição |
|---|---|
| `lib/models/audit.dart` | Model `Audit` + enum `AuditStatus` (rascunho, emAndamento, concluida, atrasada, cancelada) com label, cor e ícone |
| `lib/models/audit_answer.dart` | Model `AuditAnswer` com id, auditId, templateItemId, response, observation, answeredAt |
| `lib/services/audit_service.dart` | CRUD de auditorias: getAudits, createAudit, closeAudit, finalizeAudit, duplicateAudit, deleteAudit, updateStatus |
| `lib/services/audit_answer_service.dart` | Respostas: getAnswers, upsertAnswer (onConflict), deleteAnswer, calculateConformity |
| `lib/screens/audits_screen.dart` | Tela principal de auditorias com listagem, filtros e fluxo de criação |
| `lib/screens/audit_execution_screen.dart` | Tela de execução/visualização de auditoria com resposta por item |
| `supabase/migrations/20260406_create_audits.sql` | Migração idempotente da tabela `audits` com RLS, triggers e índices |
| `supabase/migrations/20260406_create_audit_answers.sql` | Migração idempotente da tabela `audit_answers` com upsert e RLS |

#### Arquivos modificados
| Arquivo | Mudança |
|---|---|
| `lib/screens/home_screen.dart` | Adicionado acesso à tela de auditorias via drawer |
| `lib/main.dart` | Limpeza de warning (`__` → `_`) |

---

### Detalhes das funcionalidades

#### AuditsScreen
- Listagem com busca por texto e filtros rápidos (Todas / Em andamento / Concluídas / Atrasadas / Minhas)
- Cards de auditoria com status colorido, progresso, auditor, prazo e indicador de atraso
- Ações por card: abrir/continuar, duplicar, encerrar
- Fluxo de criação em 4 etapas: tipo → template → perímetro → prazo
- ID gerado automaticamente no formato `SIGLA-YYYYMMDD-HHMM-INICIAIS` (ex: `EHS-20260406-1929-CM`)
  - Sigla extraída do tipo: `Segurança (EHS)` → `EHS` | `5S` → `5S` | `Meio Ambiente` → `MA`
- Auditor fixado como o usuário logado (sem seleção manual)
- Ao criar, já navega diretamente para a execução da auditoria

#### AuditExecutionScreen
- Carrega seções, itens e respostas existentes em paralelo
- Salva respostas automaticamente a cada interação (upsert)
- Barra de progresso no AppBar (`respondidos/total`)
- Modo leitura automático para auditorias concluídas ou canceladas
- Banner colorido indicando status final (verde = concluída, vermelho = cancelada)
- Widgets de resposta por tipo: ok_nok, yes_no, scale_1_5, percentage, text, selection
- Guidances colapsáveis por item
- Botão "Cancelar e não salvar" no menu do AppBar (apenas para auditorias não finalizadas): exclui permanentemente a auditoria
- Finalização calcula conformidade ponderada por peso de cada item

#### Regras de encerramento
- **Rascunho encerrado** → auditoria excluída permanentemente (não fica na base)
- **Em andamento / Atrasada encerrada** → marcada como cancelada
- **Concluída** → somente leitura; única ação disponível é marcar como cancelada

#### Seleção de perímetro em cascata
- Navegação hierárquica (pai → filho → neto) com breadcrumb interativo
- Seta `›` nos nós com filhos para navegar para o próximo nível
- Selecionar qualquer nível (raiz, intermediário ou folha)
- Opção "Sem perímetro" disponível no nível raiz
- Toque no item já selecionado desmarca

#### Migração SQL — padrão idempotente
Todas as migrações seguem o padrão:
1. `CREATE TABLE IF NOT EXISTS` com apenas `id`
2. `ADD COLUMN IF NOT EXISTS` para cada coluna individualmente
3. `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT` para cada FK
4. `DROP POLICY IF EXISTS` + `CREATE POLICY` para cada política RLS
5. `NOTIFY pgrst, 'reload schema'` ao final

#### Cálculo de conformidade
Ponderado por peso (`item.weight`) por tipo de resposta:
- `ok_nok` / `yes_no` → 100% do peso se positivo
- `scale_1_5` → `valor / 5 * peso`
- `percentage` → `valor / 100 * peso`
- `text` / `selection` → 100% do peso se não vazio
