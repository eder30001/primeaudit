# Phase 14: Checklist Execution Engine — Research

**Researched:** 2026-05-05
**Domain:** Flutter + Supabase — formulário de execução com auto-save, múltiplos tipos de resposta e cálculo de conformidade
**Confidence:** HIGH (todo o código base foi lido diretamente; sem dependências externas novas)

---

## Summary

A Phase 14 implementa o fluxo central do módulo de Checklist: o auditor seleciona um template, inicia uma execução preenchendo metadados de identificação, responde os itens item por item com diferentes tipos de resposta, e finaliza com cálculo de conformidade. O rascunho é salvo silenciosamente após cada resposta — sem bloqueio, sem modal de erro.

O padrão arquitetural já está completamente estabelecido em `AuditExecutionScreen` e `AuditAnswerService`. A Phase 14 replica e adapta esse padrão para o domínio de Checklist, introduzindo apenas diferenças específicas: tipos de resposta extras (`number`, `date`, `multiple_choice`), ausência de seções (os itens de checklist são planos), cálculo de conformidade simplificado (sem peso por item), e lógica de offline mais simples (sem `sqflite` — falha silenciosa pura).

Duas novas tabelas precisam ser criadas via migration: `checklist_executions` e `checklist_answers`. Além disso, a tabela `checklist_template_items` precisa de uma coluna `options` (JSONB ou TEXT[]) para suportar `multiple_choice`.

**Recomendação principal:** Replicar o padrão `_PendingSave` + retry exponencial do módulo de Auditoria integralmente. Não introduzir sqflite ou outro cache offline — o contrato de "falha silenciosa" significa que o auditor continua preenchendo e as respostas ficam na UI (in-memory) mesmo que o upsert falhe; o retry automático cuida da persistência quando a rede voltar.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXEC-01 | Usuário inicia checklist preenchendo identificação (responsável, local, data, número/código) | Modal de início → insert em `checklist_executions` com status `rascunho`. Ver Seção "Fluxo de UI". |
| EXEC-02 | Usuário responde itens com todos os tipos suportados: Sim/Não, texto, número, data, múltipla escolha | 5 widgets de resposta mapeados para `item_type`. Foto (EXEC-04) é Phase 15. Ver Seção "Tipos de Resposta". |
| EXEC-03 | Usuário adiciona observação opcional por item | Campo colapsável por item, padrão idêntico ao `_ItemCard` de `audit_execution_screen.dart`. |
| EXEC-05 | Rascunho salvo automaticamente (falha silenciosa não interrompe o checklist) | Padrão `_saveAnswer` + `_PendingSave` + retry exponencial. Ver Seção "Auto-save". |
| SC-5 | Usuário finaliza checklist; conformidade calculada e status muda para concluído | `calculateConformity()` simplificado (sem peso, `number`/`date` excluídos do denominador). Ver Seção "Conformidade". |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Modal de início (EXEC-01) | Screen (Flutter) | — | Formulário local com setState; insert só após confirmar |
| Auto-save de respostas (EXEC-05) | Screen + Service (Dart) | Supabase (upsert) | Lógica de retry vive na Screen; persistência no Supabase via service |
| Cálculo de conformidade | Service (Dart estático) | — | Pure computation, sem I/O; `static double calculateConformity(...)` |
| RLS de execuções | Database (PostgreSQL) | — | Auditor lê/escreve apenas execuções próprias; adm/superuser tem full access |
| Widgets por tipo de resposta | Screen (Flutter Widgets) | — | Switch por `item_type` dentro da Screen, sem lógica de negócio |
| Finalização (status + conformidade) | Service (Dart) | Supabase | `finalizeExecution()` faz um único UPDATE com status e conformidade |

---

## Standard Stack

### Core (já instalado — sem novos pacotes necessários)

| Library | Version | Purpose | Por que padrão |
|---------|---------|---------|----------------|
| `supabase_flutter` | `2.12.2` | Upsert de respostas, insert de execuções, RLS | Já é o backend único do projeto |
| `flutter` SDK | `>=3.38.4` | UI (Widgets de resposta, navegação) | Stack locked por CLAUDE.md |
| `shared_preferences` | `2.5.5` | Contexto de empresa ativo | Já usado pelo `CompanyContextService` |

**Nenhum pacote novo necessário para Phase 14.** Phase 15 (fotos) precisará de `image_picker`; Phase 16 (assinatura) precisará de `signature ^9.0.0`. Esses não entram nesta phase.

### Instalação

```bash
# Nenhum flutter pub add necessário para Phase 14
# Verificar versões atuais:
flutter pub deps | grep supabase_flutter
```

---

## Architecture Patterns

### Diagrama de Fluxo

```
ChecklistTemplateListScreen
   │ (tap no card de um template)
   ▼
_StartChecklistSheet (BottomSheet modal)
   │ [responsável, local, data, número/código]
   │ → ChecklistExecutionService.createExecution(...)
   │ → INSERT checklist_executions (status='rascunho')
   ▼
ChecklistExecutionScreen (StatefulWidget)
   ├── _load(): carrega itens do template + respostas existentes em paralelo
   ├── Map<String, String> _answers (in-memory, resposta por item_id)
   ├── Map<String, String> _observations (in-memory, obs por item_id)
   ├── Map<String, _PendingSave> _failedSaves (fila de retry)
   │
   ├── _onAnswer(itemId, response)
   │     ├── setState(_answers[itemId] = response)
   │     └── _saveAnswer(itemId, response)  ← fire-and-forget
   │           ├── [sucesso] remove de _failedSaves
   │           └── [falha]  adiciona a _failedSaves + _scheduleRetry()
   │
   ├── _onObservation(itemId, obs)
   │     └── _saveAnswer(itemId, currentAnswer, observation: obs)
   │
   ├── ListView de _ChecklistItemCard (sem seções — lista plana)
   │     └── _AnswerWidget (switch por item_type)
   │           ├── yes_no    → _TwoOptionButtons (Sim/Não)
   │           ├── text      → _TextAnswer (TextField)
   │           ├── number    → _NumberAnswer (TextField numérico)
   │           ├── date      → _DateAnswer (showDatePicker)
   │           └── multiple_choice → _MultipleChoiceAnswer (Wrap de chips)
   │
   └── BottomBar
         ├── Conformidade atual (ao vivo, excluindo number/date do denominador)
         └── Botão Finalizar → _finalize()
               ├── guarda: _failedSaves.isNotEmpty → dialog de bloqueio
               ├── calculateConformity(_allItems, _answers)
               └── ChecklistExecutionService.finalizeExecution(id, conformity)
```

### Estrutura de arquivos recomendada

```
primeaudit/lib/
├── models/
│   └── checklist_execution.dart          # ChecklistExecution + ChecklistAnswer
├── services/
│   ├── checklist_execution_service.dart  # CRUD execuções + finalização
│   └── checklist_answer_service.dart     # upsertAnswer + calculateConformity
├── screens/
│   └── checklist/
│       ├── checklist_execution_screen.dart  # Tela principal de execução
│       └── checklist_pending_save.dart      # _PendingSave (extraído para teste)
└── supabase/migrations/
    └── 20260506_create_checklist_executions.sql
```

---

## Detailed Technical Findings

### 1. Schema de banco necessário

**Tabelas novas:** `checklist_executions` e `checklist_answers`.
**Tabela existente a modificar:** `checklist_template_items` (coluna `options`).

#### 1.1 `checklist_executions`

```sql
CREATE TABLE IF NOT EXISTS checklist_executions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS template_id   UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS company_id    UUID;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS created_by    UUID;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS responsavel   TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS local         TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS numero        TEXT;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS data_execucao DATE        NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS status        TEXT        NOT NULL DEFAULT 'rascunho';
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS conformity_percent NUMERIC(5,2);
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS completed_at  TIMESTAMPTZ;
```

**Constraints:**
- `status CHECK (status IN ('rascunho', 'concluido'))`
- FK `template_id → checklist_templates(id) ON DELETE RESTRICT`
- FK `company_id → companies(id) ON DELETE SET NULL`
- FK `created_by → profiles(id) ON DELETE SET NULL`

**Índices:**
- `(created_by, created_at DESC)` — listagem de histórico por auditor
- `(template_id)` — estatísticas por template
- `(company_id, status)` — dashboard

**Nota:** Sem `deadline` ou `atrasada` — checklists não têm prazo nesta milestone. [VERIFIED: REQUIREMENTS.md — sem requisito de prazo em EXEC-01..06]

#### 1.2 `checklist_answers`

```sql
CREATE TABLE IF NOT EXISTS checklist_answers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS execution_id  UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS item_id       UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS response      TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS observation   TEXT;
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS answered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

**Constraints:**
- FK `execution_id → checklist_executions(id) ON DELETE CASCADE`
- FK `item_id → checklist_template_items(id) ON DELETE CASCADE`
- UNIQUE `(execution_id, item_id)` — chave de upsert (mesmo padrão de `audit_answers`)

**Índices:**
- `(execution_id)` — carregar respostas de uma execução
- `(execution_id, item_id)` — upsert lookup

#### 1.3 `checklist_template_items` — coluna `options`

A tabela atual não tem como armazenar opções de `multiple_choice`. Solução: coluna `options` como `TEXT[]` (array nativo do PostgreSQL).

```sql
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS options TEXT[];
```

**Por que `TEXT[]` e não JSONB?**
- Mais simples: nenhum parse JSON necessário; PostgREST serializa como `List<dynamic>` diretamente
- `fromMap` lê como `List<dynamic>` → `List<String>`
- UPDATE simples: `{'options': ['Opção A', 'Opção B']}` no insert/update via Dart

**Por que não tabela separada?**
- Para Phase 14 as opções são imutáveis após criação do template
- Tabela separada exigiria JOIN extra na carga de itens e lógica de cascata
- Template form (Phase 13-04) precisaria de update para gerenciar opções — scope futuro
- `TEXT[]` é suficiente para o MVP de execução

**Impacto no modelo existente:** `ChecklistTemplateItem` recebe campo opcional `List<String>? options` com parse via `(map['options'] as List?)?.cast<String>() ?? []`. [VERIFIED: codebase — fromMap pattern existente]

#### 1.4 RLS para execuções e respostas

Padrão estabelecido: mesmo modelo do `audits` (Pattern 2 — company + creator).

```sql
-- checklist_executions:
-- superuser/dev: full access
-- adm: lê/escreve todas da empresa
-- auditor: lê apenas as próprias, insere/atualiza as próprias

-- checklist_answers:
-- Pattern 3 (subquery via FK): permissão derivada da execução pai
-- Auditor pode escrever respostas da própria execução
```

[VERIFIED: migrations/20260406_create_audits.sql, migrations/20260503_create_checklist_templates.sql]

---

### 2. Auto-save sem bloqueio (EXEC-05)

O padrão está completamente implementado em `audit_execution_screen.dart`. Replicar integralmente:

**Contrato de falha silenciosa para checklist:**
- `_saveAnswer()` é `async` mas chamado sem `await` — fire-and-forget
- Em caso de falha de rede ou qualquer exceção: resposta fica em `_answers` (memória), item vai para `_failedSaves`
- `_scheduleRetry()` faz até 4 tentativas com backoff exponencial (1s, 2s, 4s, 8s)
- Snackbar "Não foi possível salvar" com action "Tentar novamente" (sem modal de erro bloqueante)
- `_finalize()` bloqueia se `_failedSaves.isNotEmpty` — usuário não perde dados ao finalizar

**O que "offline" significa na prática sem sqflite:**
- Respostas já salvas antes do WiFi cair: persistidas no Supabase
- Respostas preenchidas COM WiFi desligado: ficam em `_answers` (RAM), ficam em `_failedSaves` (fila de retry)
- Ao reconectar: retry automático via `_scheduleRetry()` as resubmete
- Se o app for fechado com WiFi desligado: respostas não persistidas são perdidas
- Esse é o contrato aceito para Phase 14 (STATE.md: "Modo offline com sync posterior — Alta complexidade — milestone futura") [VERIFIED: REQUIREMENTS.md Out of Scope]

**Reutilização de `PendingSave`:**
- `PendingSave` em `primeaudit/lib/screens/pending_save.dart` é público e pode ser reutilizado
- Alternativa: criar `ChecklistPendingSave` idêntico no diretório de checklist para manter independência de módulos
- Recomendação: criar novo arquivo `checklist_pending_save.dart` em `screens/checklist/` — módulo checklist é independente (STATE.md Decisions v1.2: "zero alterações em AuditExecutionScreen")

**Classe `ChecklistAnswerService.upsertAnswer()`:**
```dart
Future<void> upsertAnswer({
  required String executionId,
  required String itemId,
  required String response,
  String? observation,
}) async {
  await _client.from('checklist_answers').upsert(
    {
      'execution_id': executionId,
      'item_id': itemId,
      'response': response,
      'observation': observation,
      'answered_at': DateTime.now().toIso8601String(),
    },
    onConflict: 'execution_id,item_id',
  );
}
```

[VERIFIED: lib/services/audit_answer_service.dart — padrão idêntico]

---

### 3. Tipos de resposta (EXEC-02)

A `checklist_template_items.item_type` suporta: `yes_no`, `text`, `number`, `date`, `multiple_choice`, `photo`.

**Phase 14 implementa 5 tipos** (foto é Phase 15):

| `item_type` | Widget | Valor salvo como `response` | Notas |
|-------------|--------|-----------------------------|-------|
| `yes_no` | `_TwoOptionButtons` (Sim/Não) | `'yes'` ou `'no'` | Copiado exatamente de `audit_execution_screen.dart` |
| `text` | `_TextAnswer` (TextField multiline) | string livre | Copiado exatamente |
| `number` | `_NumberAnswer` (TextField numérico) | string do número (`'42.5'`) | NOVO: `keyboardType: TextInputType.numberWithOptions(decimal: true)` |
| `date` | `_DateAnswer` (showDatePicker) | ISO 8601 date string (`'2026-05-05'`) | NOVO: `showDatePicker()` + formatar com `DateFormat('yyyy-MM-dd')` |
| `multiple_choice` | `_MultipleChoiceAnswer` (Wrap de chips) | string da opção selecionada | NOVO: opções vêm de `item.options` (coluna nova) |
| `photo` | placeholder (`SizedBox` com ícone) | — | Phase 15 — renderizar badge "Foto disponível na próxima versão" |

**Widget `_NumberAnswer`:**
```dart
// TextField numérico — dispara onChanged (fire-and-forget para _saveAnswer)
TextField(
  controller: _ctrl,
  keyboardType: TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
  onChanged: widget.readOnly ? null : widget.onChanged,
  // ...
)
```

**Widget `_DateAnswer`:**
```dart
// Botão que abre showDatePicker; valor formatado como 'yyyy-MM-dd'
OutlinedButton.icon(
  icon: const Icon(Icons.calendar_today_outlined, size: 16),
  label: Text(displayDate),  // dd/MM/yyyy para display, yyyy-MM-dd no _answers
  onPressed: widget.readOnly ? null : () async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parsedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      widget.onAnswer(DateFormat('yyyy-MM-dd').format(picked));
    }
  },
)
```

**Widget `_MultipleChoiceAnswer`:**
```dart
// Wrap de chips — padrão _SelectionAnswer já existente em audit_execution_screen.dart
// Diferença: opções vêm de item.options (List<String>) em vez de TemplateItem.options
Wrap(
  spacing: 8, runSpacing: 6,
  children: item.options.map((opt) => GestureDetector(
    onTap: readOnly ? null : () => onAnswer(opt),
    child: AnimatedContainer(/* chip estilizado */),
  )).toList(),
)
```

**Nota importante sobre `number` e `date` no formulário de criação (Phase 13-04):**
Phase 13-04 já está entregue e o `ChecklistTemplateFormScreen` não tem campos para configurar opções de `multiple_choice` nem labels para `number`/`date`. Para Phase 14:
- `multiple_choice` sem opções configuradas: renderizar mensagem "Nenhuma opção configurada" (mesmo padrão do `_SelectionAnswer` existente)
- Seeds de template não têm `multiple_choice` (verificado no SQL de seeds) — não há risco imediato

[VERIFIED: migrations/20260503_create_checklist_templates.sql seeds]

---

### 4. Cálculo de conformidade (SC-5)

**Decisão registrada em STATE.md (v1.2):** "Tipos number e date excluídos do denominador do cálculo de conformidade" [VERIFIED: STATE.md Decisions v1.2]

**Lógica para checklist (sem peso por item, diferente do módulo de Auditoria):**

```dart
static double calculateConformity(
  List<ChecklistTemplateItem> items,
  Map<String, String> answers,
) {
  // Apenas yes_no, text, multiple_choice entram no denominador
  // number e date são excluídos (são informativos)
  // photo é excluído (Phase 15)
  const conformityTypes = {'yes_no', 'text', 'multiple_choice'};
  
  final eligible = items.where((i) => conformityTypes.contains(i.itemType)).toList();
  if (eligible.isEmpty) return 100.0;
  
  int total = eligible.length;
  int conforming = 0;
  
  for (final item in eligible) {
    final ans = answers[item.id];
    if (ans == null || ans.isEmpty) continue;
    
    switch (item.itemType) {
      case 'yes_no':
        if (ans == 'yes') conforming++;      // Sim = conforme
      case 'text':
        if (ans.isNotEmpty) conforming++;    // Qualquer texto = conforme
      case 'multiple_choice':
        if (ans.isNotEmpty) conforming++;    // Qualquer seleção = conforme
    }
  }
  
  return (conforming / total * 100).clamp(0.0, 100.0);
}
```

**Diferença do módulo de Auditoria:** sem `weight` por item (todos têm peso igual 1). O módulo de Auditoria tem `TemplateItem.weight` e diferentes tipos (`ok_nok`, `scale_1_5`, `percentage`). O módulo de Checklist usa apenas `yes_no` = Sim/Não, e o denominador é count simples.

**Itens de `yes_no` com resposta `'no'` (Não):** contribuem para o denominador mas não somam conformidade — `'no'` = não conforme. Itens sem resposta não entram no cálculo (não penalizam, permitem finalização parcial se não houver obrigatoriedade de campo).

**Nota:** O modelo atual de `checklist_template_items` não tem campo `required`. Para Phase 14, todos os itens são considerados opcionais para finalização (sem bloqueio por itens não respondidos) — consistente com EXEC-01..EXEC-05 que não mencionam obrigatoriedade de item. [ASSUMED — confirmar se `required` deve ser adicionado ao schema]

---

### 5. Fluxo de UI (sequência de telas)

#### Ponto de entrada: `ChecklistTemplateListScreen`

O card de template na `ChecklistTemplateListScreen` atualmente navega para edição (`onEdit`) ou clona (`onClone`) ao ser tocado. Para execução, o card precisa de um botão/ação "Executar checklist".

**Decisão de design recomendada:** Adicionar botão "Executar" no card de template — tanto para seeds quanto para templates próprios. O toque no card continua com o comportamento atual (editar para próprio, clonar para seed). Um `ElevatedButton` ou `IconButton` secundário no trailing area dispara o fluxo de execução.

Alternativa: toque no card = executar, ícone de menu = opções de gerenciamento. Mais simples para auditores. [ASSUMED — decisão de UX a confirmar com usuário]

#### Modal de início: `_StartChecklistSheet`

`BottomSheet` modal com formulário (padrão `_NewAuditSheet` de `home_screen.dart`):

```
Campos:
- Responsável (TextFormField — obrigatório)
- Local (TextFormField — obrigatório)  
- Data de execução (DatePicker — obrigatório, default = hoje)
- Número/código (TextFormField — opcional)
```

Ao confirmar: `ChecklistExecutionService.createExecution(...)` → INSERT em `checklist_executions` → navegar para `ChecklistExecutionScreen`.

#### Tela de execução: `ChecklistExecutionScreen`

Estrutura idêntica a `AuditExecutionScreen` com diferenças:
- Sem seções (lista plana de itens — `checklist_template_items` não tem seção)
- 5 widgets de resposta (ver Seção 3)
- AppBar com título do template + progresso answered/total
- BottomBar com conformidade ao vivo + botão Finalizar

#### Finalização

Ao tocar "Finalizar":
1. Guarda: `_failedSaves.isNotEmpty` → dialog bloqueante
2. Dialog de confirmação com itens respondidos e conformidade
3. `ChecklistExecutionService.finalizeExecution(id, conformity)` → UPDATE status='concluido' + conformity_percent + completed_at
4. `Navigator.pop(true)` → volta para `ChecklistTemplateListScreen`

**Sem tela de resultado separada** em Phase 14 (Phase 17 implementa histórico). Snackbar de sucesso na tela de lista é suficiente.

---

### 6. `multiple_choice` sem opções — estratégia para Phase 14

**Situação:** `checklist_template_items` atualmente não tem coluna `options`. Seeds do banco não usam `multiple_choice`. O `ChecklistTemplateFormScreen` (Phase 13-04) não permite configurar opções.

**Solução para Phase 14:**
1. Adicionar `ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS options TEXT[];` na migration
2. Em `ChecklistTemplateItem.fromMap`: `options = (map['options'] as List?)?.cast<String>() ?? []`
3. Se `item.options.isEmpty` e `item.itemType == 'multiple_choice'`: renderizar widget vazio com mensagem "Nenhuma opção configurada" (mesmo padrão `_SelectionAnswer` existente)
4. O `ChecklistTemplateFormScreen` pode ser atualizado em uma quick task futura para configurar opções

**Risco mitigado:** Seeds não usam `multiple_choice`, então a experiência de execução dos seeds não é afetada. Templates customizados criados via Phase 13-04 também não têm `multiple_choice` porque o form não oferece essa opção. O tipo existe no CHECK constraint mas não é explorável pelo usuário final ainda.

[VERIFIED: migrations/20260503_create_checklist_templates.sql — seeds não usam multiple_choice]

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez | Por que |
|----------|---------------|-------------|---------|
| Retry com backoff | Loop customizado do zero | Padrão `_scheduleRetry` já em `audit_execution_screen.dart` | Já tem `_maxAutoRetryAttempts`, guarda de `_retrying`, `Future.delayed` com `pow()` |
| Upsert idempotente | INSERT + DELETE manual | `_client.from(...).upsert(..., onConflict: ...)` | PostgREST upsert via UNIQUE constraint — já estabelecido em `AuditAnswerService` |
| Picker de data | DatePicker customizado | `showDatePicker()` nativo Flutter Material | Já é Material 3, localização automática |
| Formatação de número | Parse/format manual | `FilteringTextInputFormatter` + `TextInputType.numberWithOptions` | Flutter já provê — sem dependência externa |
| Cálculo de conformidade | SQL agregado no banco | `static double calculateConformity(...)` em Dart | Pure computation — mais rápido, mais testável, sem round-trip de rede |

---

## Common Pitfalls

### Pitfall 1: `use_build_context_synchronously` em `_saveAnswer`

**O que vai errado:** Usar `context` após `await` dentro de `_saveAnswer` ou `_scheduleRetry` — linter Flutter recusa e causa runtime crash após `dispose()`.

**Por que acontece:** `_saveAnswer` é `async`; o widget pode ser desmontado durante o `await`. `context` fica inválido.

**Como evitar:** Sempre checar `if (!mounted) return;` antes de qualquer uso de `context` pós-`await`. Capturar `ScaffoldMessenger.of(context)` ANTES do `await` (como em `_CloneBottomSheet._clone()`).

[VERIFIED: lib/screens/checklist/checklist_template_list_screen.dart — padrão já estabelecido no projeto]

### Pitfall 2: `onConflict` ausente no upsert → PostgreSQL error

**O que vai errado:** Chamar `.upsert(data)` sem `onConflict:` em `checklist_answers` resulta em erro 409 quando o item já tem resposta.

**Como evitar:** `onConflict: 'execution_id,item_id'` — exatamente como `AuditAnswerService` usa `onConflict: 'audit_id,template_item_id'`.

**Pré-requisito:** A constraint UNIQUE `(execution_id, item_id)` deve estar na migration antes do primeiro upsert.

[VERIFIED: lib/services/audit_answer_service.dart]

### Pitfall 3: `_answers` desatualizado ao calcular conformidade após reload

**O que vai errado:** Se `_load()` for chamado novamente (ex: RefreshIndicator), o `Map<String, String> _answers` é sobrescrito sem preservar respostas em `_failedSaves` que ainda não foram persistidas no banco.

**Como evitar:** Ao recarregar, não limpar respostas que estão em `_failedSaves` — mesclar respostas do banco com as in-memory não salvas. Padrão: `final merged = Map<String, String>.from(serverAnswers); merged.addAll(_failedSaves.map((k, v) => MapEntry(k, v.response)));`

### Pitfall 4: `DATE` vs `TIMESTAMPTZ` para `data_execucao`

**O que vai errado:** Usar `TIMESTAMPTZ` para a data de execução causa problemas de timezone (UTC midnight → dia anterior no Brazil UTC-3), como documentado em `Audit._parseDateOnly()`.

**Como evitar:** Usar `DATE` no PostgreSQL para `data_execucao` — apenas a data sem timezone. No Dart, serializar como `'yyyy-MM-dd'` sem conversão de timezone.

[VERIFIED: lib/models/audit.dart — `_parseDateOnly()` documenta o problema]

### Pitfall 5: `TextEditingController` não descartado

**O que vai errado:** `_TextAnswer`, `_NumberAnswer`, e o campo de observação criam `TextEditingController`. Se não forem descartados em `dispose()`, há memory leak e warning no Flutter.

**Como evitar:** Todo `StatefulWidget` que cria controllers deve ter `@override void dispose() { _ctrl.dispose(); super.dispose(); }`. [VERIFIED: `_TextAnswerState.dispose()` em `audit_execution_screen.dart`]

### Pitfall 6: `multiple_choice` — opção selecionada não encontrada na lista atualizada

**O que vai errado:** Se as opções de um item mudarem entre a criação da execução e a resposta (ex: template editado durante execução ativa), a resposta salva pode não corresponder a nenhuma opção atual.

**Como evitar:** Para Phase 14, `options` é carregada uma vez no `_load()` e não é atualizada. O item responde com a string exata da opção. Ao exibir, se `answer` não estiver em `item.options`, mostrar como chip destacado/diferente ("resposta anterior"). Baixo risco na prática para v1.2.

---

## Code Examples

### Modelo `ChecklistExecution`

```dart
// [VERIFIED: pattern from lib/models/audit.dart]
class ChecklistExecution {
  final String id;
  final String templateId;
  final String templateName; // join
  final String? companyId;
  final String createdBy;
  final String responsavel;
  final String local;
  final String? numero;
  final DateTime dataExecucao;
  final String status; // 'rascunho' | 'concluido'
  final double? conformityPercent;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory ChecklistExecution.fromMap(Map<String, dynamic> map) {
    return ChecklistExecution(
      id: map['id'],
      templateId: map['template_id'],
      templateName: map['checklist_templates']?['name'] ?? '',
      companyId: map['company_id'],
      createdBy: map['created_by'],
      responsavel: map['responsavel'] ?? '',
      local: map['local'] ?? '',
      numero: map['numero'],
      dataExecucao: DateTime.parse(map['data_execucao']),
      status: map['status'] ?? 'rascunho',
      conformityPercent: (map['conformity_percent'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at']).toLocal()
          : null,
    );
  }

  bool get isConcluido => status == 'concluido';
}
```

### `ChecklistExecutionService.createExecution()`

```dart
// [VERIFIED: pattern from lib/services/audit_service.dart createAudit()]
Future<ChecklistExecution> createExecution({
  required String templateId,
  required String? companyId,
  required String responsavel,
  required String local,
  String? numero,
  required DateTime dataExecucao,
}) async {
  final userId = _client.auth.currentUser!.id;
  final result = await _client
      .from('checklist_executions')
      .insert({
        'template_id': templateId,
        'company_id': companyId,
        'created_by': userId,
        'responsavel': responsavel,
        'local': local,
        'numero': numero,
        'data_execucao': DateFormat('yyyy-MM-dd').format(dataExecucao),
        'status': 'rascunho',
      })
      .select('*, checklist_templates(name)')
      .single();
  return ChecklistExecution.fromMap(result);
}
```

### `ChecklistExecutionService.finalizeExecution()`

```dart
// [VERIFIED: pattern from lib/services/audit_service.dart finalizeAudit()]
Future<void> finalizeExecution({
  required String id,
  required double conformityPercent,
}) async {
  await _client.from('checklist_executions').update({
    'status': 'concluido',
    'conformity_percent': conformityPercent,
    'completed_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}
```

### `_saveAnswer` no `ChecklistExecutionScreen`

```dart
// [VERIFIED: pattern from lib/screens/audit_execution_screen.dart _saveAnswer()]
Future<void> _saveAnswer(
  String itemId,
  String response, {
  String? observation,
}) async {
  final obs = observation ?? _observations[itemId];
  try {
    await _answerService.upsertAnswer(
      executionId: widget.execution.id,
      itemId: itemId,
      response: response,
      observation: obs,
    );
    if (_failedSaves.containsKey(itemId) && mounted) {
      setState(() => _failedSaves.remove(itemId));
    }
  } catch (e) {
    debugPrint('[_saveAnswer] itemId=$itemId erro: $e');
    if (!mounted) return;
    setState(() {
      _failedSaves[itemId] = ChecklistPendingSave(
        itemId: itemId,
        response: response,
        observation: obs,
      );
    });
    _showSaveError(itemId, response, obs);
    _scheduleRetry(itemId);
  }
}
```

---

## Runtime State Inventory

Esta é uma fase greenfield de novas tabelas. Nenhum dado de runtime existente é afetado.

| Categoria | Itens encontrados | Ação necessária |
|-----------|-------------------|-----------------|
| Dados armazenados | Nenhum — tabelas `checklist_executions`/`checklist_answers` não existem ainda | Migration cria do zero |
| Config de serviço live | Nenhuma — sem n8n workflows ou dashboards para checklist_executions | — |
| Estado registrado no OS | Nenhum | — |
| Secrets/env vars | Nenhum — mesma `SUPABASE_URL` e `SUPABASE_ANON_KEY` existentes | — |
| Build artifacts | Nenhum — nenhum pacote novo adicionado | — |

---

## Environment Availability

| Dependência | Necessário para | Disponível | Fallback |
|-------------|----------------|-----------|----------|
| Supabase (db push) | Aplicar migration | Assume disponível | — |
| `intl` package (DateFormat) | Formatar datas | Verificar `pubspec.lock` | `DateTime.toIso8601String().substring(0, 10)` |

**Verificar `intl`:**

```bash
grep 'intl' primeaudit/pubspec.lock
```

Se `intl` não estiver no lockfile, usar `DateTime.toIso8601String().substring(0, 10)` como fallback para formatação de data — sem adicionar dependência nova para Phase 14.

---

## Validation Architecture

### Test Framework

| Propriedade | Valor |
|-------------|-------|
| Framework | `flutter_test` (SDK) |
| Config file | nenhum — flutter test executa por convenção |
| Comando rápido | `flutter test test/checklist_answer_service_test.dart` |
| Suite completa | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Comportamento | Tipo | Comando | Arquivo existe? |
|--------|--------------|------|---------|----------------|
| EXEC-01 | createExecution retorna objeto com status rascunho | unit | `flutter test test/checklist_execution_service_test.dart` | Não — Wave 0 |
| EXEC-02/yes_no | resposta 'yes'/'no' salva via upsertAnswer | unit | `flutter test test/checklist_answer_service_test.dart` | Não — Wave 0 |
| EXEC-02/number | resposta numérica salva como string | unit | incluído no mesmo arquivo | Não — Wave 0 |
| EXEC-02/date | resposta de data salva como 'yyyy-MM-dd' | unit | incluído no mesmo arquivo | Não — Wave 0 |
| EXEC-03 | observação salva junto com resposta | unit | incluído no mesmo arquivo | Não — Wave 0 |
| EXEC-05 | falha de upsert não lança exceção na tela | unit (mock) | `flutter test test/checklist_pending_save_test.dart` | Não — Wave 0 |
| SC-5 | calculateConformity exclui number/date do denominador | unit | `flutter test test/checklist_conformity_test.dart` | Não — Wave 0 |

### Wave 0 Gaps

- [ ] `test/checklist_execution_service_test.dart` — cobre EXEC-01
- [ ] `test/checklist_answer_service_test.dart` — cobre EXEC-02, EXEC-03
- [ ] `test/checklist_conformity_test.dart` — cobre SC-5 (calculateConformity)
- [ ] `test/checklist_pending_save_test.dart` — cobre EXEC-05 (padrão já em `test/pending_save_test.dart`)

### Sampling Rate

- **Por commit de task:** `flutter test test/checklist_conformity_test.dart -x`
- **Por wave merge:** `flutter test`
- **Phase gate:** Suite completa verde antes de `/gsd-verify-work`

---

## Security Domain

### Applicable ASVS Categories

| Categoria ASVS | Aplica | Controle padrão |
|----------------|--------|-----------------|
| V2 Authentication | Sim (indireta) | `auth.uid()` via RLS — Supabase JWT |
| V3 Session Management | Não | Gerenciado pelo Supabase SDK |
| V4 Access Control | Sim | RLS policies: auditor lê/escreve apenas próprias execuções |
| V5 Input Validation | Sim (parcial) | CHECK constraints no banco; sem validação de XSS (app nativo) |
| V6 Cryptography | Não | Sem criptografia de dados de checklist — anon key é pública by design |

### Threat Patterns

| Padrão | STRIDE | Mitigação padrão |
|--------|--------|-----------------|
| Auditor lê execuções de outra empresa | Information Disclosure | RLS: `company_id = get_my_company_id()` |
| Auditor modifica conformidade diretamente | Tampering | RLS UPDATE apenas próprias execuções; conformidade calculada no cliente |
| Inserção com `created_by` forjado | Spoofing | RLS WITH CHECK: `created_by = auth.uid()` |
| Dados de resposta em branco forçados | Tampering | `response TEXT NOT NULL DEFAULT ''` + CHECK no cliente antes de upsert |

---

## State of the Art

| Abordagem antiga | Abordagem atual (v1.2) | Impacto |
|-----------------|------------------------|---------|
| Sem módulo de checklist | Módulo independente de auditoria | Zero acoplamento; RLS, modelos e services separados |
| Upsert manual com delete+insert | PostgREST `.upsert(onConflict:)` | Idempotente, sem race condition |
| Conformidade calculada no banco (trigger) | Calculada em Dart + salva no UPDATE final | Mais rápida, offline-friendly, testável |

---

## Assumptions Log

| # | Claim | Section | Risco se errado |
|---|-------|---------|----------------|
| A1 | `multiple_choice` options armazenadas como `TEXT[]` em vez de tabela separada | Schema (1.3) | Precisaria de migração com tabela extra + join; sem impacto funcional em Phase 14 pois seeds não usam multiple_choice |
| A2 | Sem campo `required` nos itens de checklist — todos opcionais para finalização | Conformidade (4) | Se `required` for necessário, nova coluna na migration e lógica de bloqueio na finalização |
| A3 | Ponto de entrada de execução = botão "Executar" secundário no card da `ChecklistTemplateListScreen` | Fluxo de UI (5) | Alternativa: toque no card = executar. UX a confirmar |
| A4 | `intl` package disponível no lockfile para `DateFormat` | Environment (2.6) | Fallback: `toIso8601String().substring(0, 10)` — sem impacto funcional |
| A5 | Conformidade: `yes_no='no'` = não conforme (não soma), qualquer `text` não vazio = conforme | Conformidade (4) | Regra de negócio a confirmar: texto livre pode ser "N/A" — sem critério claro de conformidade |

---

## Open Questions (RESOLVED)

1. **`required` por item de checklist?**
   - O que sabemos: `checklist_template_items` não tem coluna `required`; `AuditExecutionScreen` bloqueia finalização por itens obrigatórios não respondidos
   - O que é incerto: checklists têm conceito de item obrigatório em Phase 14?
   - RESOLVED: para Phase 14, sem `required` — todos os itens são opcionais para finalização; adicionar em Phase futura se necessário

2. **Botão "Executar" no card vs. toque no card**
   - O que sabemos: toque atual vai para edição (próprio) ou clone (seed)
   - O que é incerto: onde exatamente fica o trigger de execução no card
   - RESOLVED: botão `ElevatedButton` "Executar" no rodapé do card, consistente com o padrão de ação primária em outros módulos

3. **Conformidade: texto livre é sempre conforme?**
   - O que sabemos: no módulo de Auditoria, `text` = qualquer resposta não vazia = conforme
   - O que é incerto: para checklists, "texto em branco após abrir o campo" deve ser ignorado ou penalizado?
   - RESOLVED: mesma regra do módulo de Auditoria — texto não vazio = conforme; não respondido = excluído do cálculo

---

## Sources

### Primary (HIGH confidence)

- `[VERIFIED: lib/screens/audit_execution_screen.dart]` — padrão completo de auto-save, retry, widgets de resposta, finalização
- `[VERIFIED: lib/services/audit_answer_service.dart]` — padrão upsert com onConflict
- `[VERIFIED: lib/services/audit_service.dart]` — padrão createExecution/finalizeExecution
- `[VERIFIED: supabase/migrations/20260406_create_audits.sql]` — padrão de migration idempotente + RLS
- `[VERIFIED: supabase/migrations/20260503_create_checklist_templates.sql]` — schema Phase 13, seeds, RLS patterns
- `[VERIFIED: lib/models/checklist_template.dart]` — modelo existente, fromMap pattern
- `[VERIFIED: lib/services/checklist_template_service.dart]` — service existente, padrão cloneTemplate com rollback
- `[VERIFIED: lib/screens/checklist/checklist_template_list_screen.dart]` — ponto de entrada do fluxo
- `[VERIFIED: lib/screens/pending_save.dart]` — PendingSave, copyWithAttempt
- `[VERIFIED: .planning/STATE.md Decisions v1.2]` — "Tipos number e date excluídos do denominador"
- `[VERIFIED: .planning/REQUIREMENTS.md]` — EXEC-01..06, Out of Scope ("Modo offline com sync posterior")

### Secondary (MEDIUM confidence)

- `[CITED: Flutter docs — showDatePicker]` — API nativa Material, sem verificação Context7 nesta sessão
- `[CITED: Flutter docs — FilteringTextInputFormatter]` — padrão para campo numérico

---

## Metadata

**Confidence breakdown:**
- Schema de banco: HIGH — baseado em migrations existentes e decisões do STATE.md
- Auto-save pattern: HIGH — código fonte do padrão existente lido diretamente
- Tipos de resposta (yes_no, text): HIGH — código copiável diretamente de audit_execution_screen.dart
- Tipos novos (number, date, multiple_choice): MEDIUM — padrão Flutter padrão, sem verificação em Context7
- Conformidade: HIGH — lógica derivada do AuditAnswerService + STATE.md decision
- RLS policies: HIGH — padrão das migrations existentes replicado

**Research date:** 2026-05-05
**Valid until:** 2026-06-05 (dependências estáveis, sem fast-moving packages)
