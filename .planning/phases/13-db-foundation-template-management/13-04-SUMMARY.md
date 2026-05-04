---
phase: 13-db-foundation-template-management
plan: 04
subsystem: ui
tags: [dart, flutter, material3, checklist, forms, statefulwidget]

# Dependency graph
requires:
  - phase: 13-02
    provides: "ChecklistTemplate, ChecklistTemplateItem models e ChecklistTemplateService com createTemplate, createItems, updateTemplate, replaceItems, getItems"
provides:
  - "ChecklistTemplateFormScreen — tela full-screen de criação/edição de templates de checklist"
  - "Create mode: cria template + items via ChecklistTemplateService.createTemplate + createItems"
  - "Edit mode: carrega items existentes + atualiza via updateTemplate + replaceItems"
  - "Validação de campos obrigatórios (nome, categoria) e lista mínima (ao menos 1 item)"
  - "_ItemRow widget reutilizável com TextFormField + DropdownButton de tipo + botão remover"
affects: [13-03-checklist-templates-screen, 14-checklist-execution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Form screen pattern: StatefulWidget full-screen (não bottom sheet) para formulários com lista variável"
    - "_inputDec helper method na State class (sem parâmetro BuildContext — usa context do State)"
    - "Items list pattern: List<Map<String,dynamic>> com 'ctrl' (TextEditingController) + 'item_type' (String)"
    - "_ItemRow StatelessWidget: campo de texto + DropdownButton + IconButton alinhados em Row"
    - "Edit mode item loading: _loadItems() em initState com mounted guard no setState"
    - "Pitfall 5 avoidance: itemMaps construído a partir da posição atual da lista, order_index atribuído pelo service"

key-files:
  created:
    - primeaudit/lib/screens/checklist/checklist_template_form_screen.dart
  modified: []

key-decisions:
  - "DropdownButtonFormField usa initialValue (não value) — value foi depreciado no Flutter 3.33.0-1.0.pre"
  - "_inputDec é método da State class (não top-level) — acessa context diretamente via AppTheme.of(context)"
  - "_ItemRow é StatelessWidget (não StatefulWidget) — recebe ctrl e callbacks do parent, sem estado local"
  - "validator em cada _ItemRow TextField: campo de descrição é obrigatório na submissão do form"

patterns-established:
  - "Pattern: Form screen full-page para formulários com lista dinâmica de itens (vs bottom sheet para formulários simples)"
  - "Pattern: _isLoadingItems separado de _isSaving — dois estados async independentes na mesma tela"
  - "Pattern: dispose() loop sobre _items para liberar controllers filhos além dos controllers top-level"

requirements-completed:
  - TMPLCK-02
  - TMPLCK-03

# Metrics
duration: 9min
completed: 2026-05-04
---

# Phase 13 Plan 04: ChecklistTemplateFormScreen (create + edit) Summary

**ChecklistTemplateFormScreen full-screen StatefulWidget com suporte a criação e edição de templates, lista dinâmica de itens com add/remove, validação de form e integração com ChecklistTemplateService**

## Performance

- **Duration:** 9 min
- **Started:** 2026-05-04T11:27:50Z
- **Completed:** 2026-05-04T11:36:40Z
- **Tasks:** 1 de 1 completa
- **Files modified:** 1

## Accomplishments

- ChecklistTemplateFormScreen implementada com dois modos: create (editing==null) e edit (editing!=null)
- Campos de formulário: nome (required, TextCapitalization.words), categoria (DropdownButtonFormField, required), descrição (opcional, maxLines: 3)
- Lista de itens com _ItemRow (TextFormField + DropdownButton de tipo + botão remover) e botão "Adicionar item"
- Validação completa: 'Obrigatório' em nome/categoria, 'Adicione ao menos um item' se lista vazia
- _save() com paths distintos: createTemplate+createItems (create) ou updateTemplate+replaceItems (edit)
- Spinner inline no botão durante _isSaving + botão desabilitado durante operação assíncrona
- _loadItems() carrega itens existentes em modo de edição com mounted guard e tratamento de erro

## Task Commits

Commits atômicos por task:

1. **Task 1: Create ChecklistTemplateFormScreen (create + edit mode, items list)** - `2d6d899` (feat)

## Files Created/Modified

- `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart` — ChecklistTemplateFormScreen + _ItemRow; 357 linhas

## Decisions Made

- `DropdownButtonFormField` usa `initialValue` em vez de `value` — o parâmetro `value` foi depreciado no Flutter 3.33.0-1.0.pre. O analyze retornou `deprecated_member_use` na primeira tentativa; corrigido para `initialValue` na mesma sessão antes do commit.
- `_inputDec` é método da State class que acessa `context` diretamente (via `this.context`), sem precisar receber `BuildContext ctx` como parâmetro extra — padrão mais limpo para State methods.
- `_ItemRow` implementado como `StatelessWidget` (não `StatefulWidget`) — os dados de estado (`ctrl` e `itemType`) vivem em `_items` na State pai; _ItemRow só renderiza e dispara callbacks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrigido uso de `value` depreciado em DropdownButtonFormField**
- **Found during:** Task 1 — verificação via flutter analyze
- **Issue:** `value: _category` dispara `deprecated_member_use` no Flutter 3.38.4 (`value` depreciado desde 3.33.0-1.0.pre em favor de `initialValue`)
- **Fix:** Substituído `value: _category` por `initialValue: _category`
- **Files modified:** `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart`
- **Verification:** `flutter analyze lib/screens/checklist/checklist_template_form_screen.dart` → No issues found
- **Committed in:** `2d6d899` (task commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug: deprecated API)
**Impact on plan:** Fix essencial para zero warnings. Sem scope creep.

## Issues Encountered

Nenhum além da deprecação acima, que foi resolvida automaticamente antes do commit.

## User Setup Required

Nenhum — o formulário é código Dart puro que usa o service e models já implementados no Plan 13-02. Nenhuma migração de banco nova. Nenhuma configuração de serviço externo.

## Known Stubs

Nenhum stub. O formulário está completamente implementado:
- Create mode chama `createTemplate` + `createItems` com dados reais do form
- Edit mode chama `updateTemplate` + `replaceItems` com dados reais do form
- A tela faz pop após save bem-sucedido; o parent (Plan 13-03) chama `_load()` para refresh

## Threat Flags

Nenhum. Mitigações do threat register implementadas:
- T-13-10 (is_padrao tampering): `createTemplate` hardcoda `is_padrao: false` no service — o form não tem campo para isso
- T-13-11 (edit de template alheio): mesmo que o UI abra edit para template alheio, `updateTemplate` + RLS rejeitam no banco (`created_by = auth.uid() AND is_padrao = false`)

## Next Phase Readiness

- Plan 13-03 (ChecklistTemplatesScreen) pode importar `checklist_template_form_screen.dart` imediatamente
- O form usa `Navigator.of(context).pop()` ao concluir — o parent só precisa chamar `_load()` no `.then()` do push
- Plan 14 (Checklist Execution Engine) não depende desta tela diretamente

---

## Self-Check: PASSED

- [x] `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart` — FOUND
- [x] Commit `2d6d899` existe no repositório
- [x] `flutter analyze lib/screens/checklist/checklist_template_form_screen.dart` — No issues found
- [x] `flutter test --no-pub` — 264 passed, 2 skipped (sem regressões)
- [x] Acceptance criteria verificados: class, editing, formKey, DropdownButtonFormField, validators, service calls, _isSaving, CircularProgressIndicator, TextCapitalization.words, CTAs, dispose()

*Phase: 13-db-foundation-template-management*
*Plan: 04*
*Completed: 2026-05-04*
