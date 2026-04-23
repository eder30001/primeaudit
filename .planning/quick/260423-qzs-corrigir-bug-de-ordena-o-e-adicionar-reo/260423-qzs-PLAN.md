---
phase: quick-260423-qzs
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - primeaudit/lib/services/audit_template_service.dart
  - primeaudit/lib/screens/templates/template_builder_screen.dart
autonomous: true
requirements:
  - TMPL-02
must_haves:
  truths:
    - "Reordenar itens dentro de uma seção não causa erro de constraint NOT NULL"
    - "Reordenar itens na lista sem-seção não causa erro de constraint NOT NULL"
    - "Seções podem ser reordenadas via drag & drop no TemplateBuilderScreen"
    - "Um handle de arraste aparece no cabeçalho de cada seção"
    - "Falha ao salvar ordem não causa setState após widget desmontado"
  artifacts:
    - path: primeaudit/lib/services/audit_template_service.dart
      provides: "reorderItems corrigido + reorderSections novo"
      contains: "defaultToNull: false"
    - path: primeaudit/lib/screens/templates/template_builder_screen.dart
      provides: "ReorderableListView para seções + guards mounted"
      contains: "ReorderableListView"
  key_links:
    - from: primeaudit/lib/screens/templates/template_builder_screen.dart
      to: primeaudit/lib/services/audit_template_service.dart
      via: "_persistSectionsOrder chama reorderSections"
      pattern: "_service.reorderSections"
---

<objective>
Corrigir o bug de ordenação de itens no TemplateBuilderScreen (upsert sobrescrevia campos NOT NULL por omissão) e adicionar suporte a reordenação de seções via drag & drop.

Purpose: O bug faz o reorder de itens lançar exceção de constraint do banco — tornando a funcionalidade inutilizável em produção. A ausência de drag de seções é uma lacuna de UX óbvia agora que itens têm drag.

Output:
- `audit_template_service.dart` com `defaultToNull: false` em ambos os upserts e novo método `reorderSections`
- `template_builder_screen.dart` com ReorderableListView envolvendo as seções, handle de arraste no cabeçalho de cada seção, `_persistSectionsOrder`, e guards `if (mounted)` nos catch blocks
</objective>

<execution_context>
@/home/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md

<interfaces>
<!-- Contrato atual relevante — extraído do codebase antes da edição -->

De primeaudit/lib/services/audit_template_service.dart (linha 211-218):
```dart
Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client.from('template_items').upsert(payload); // BUG: defaultToNull omitido
}
// Fim da classe (linha 219) — reorderSections não existe ainda
```

De primeaudit/lib/screens/templates/template_builder_screen.dart:
```dart
// linha 364 — _persistSectionOrder (mounted guard ausente)
Future<void> _persistSectionOrder(TemplateSection section) async {
  try {
    await _service.reorderItems(section.items.map((i) => i.id).toList());
  } catch (_) {
    _showError('Erro ao salvar nova ordem. A ordem foi restaurada.');
    _load(); // BUG: sem if (mounted)
  }
}

// linha 375 — _persistUnsectionedOrder (mounted guard ausente)
Future<void> _persistUnsectionedOrder() async {
  try {
    await _service.reorderItems(_items.map((i) => i.id).toList());
  } catch (_) {
    _showError('Erro ao salvar nova ordem. A ordem foi restaurada.');
    _load(); // BUG: sem if (mounted)
  }
}

// linha 471 — seções como flat map (sem ReorderableListView)
..._sections.map((s) => _buildSection(s)),

// linha 499 — _buildSection sem parâmetro de índice
Widget _buildSection(TemplateSection section) { ... }
// header Row: Icon(folder) | Text(name) | Text(N itens) | PopupMenuButton
// SEM drag handle
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Corrigir reorderItems e criar reorderSections no service</name>
  <files>primeaudit/lib/services/audit_template_service.dart</files>
  <action>
Duas alterações neste arquivo:

1. Na linha 217, substituir:
   ```dart
   await _client.from('template_items').upsert(payload);
   ```
   por:
   ```dart
   await _client.from('template_items').upsert(payload, defaultToNull: false);
   ```
   Justificativa: sem `defaultToNull: false`, o PostgREST tenta setar para NULL as colunas não especificadas no payload (apenas `id` e `order_index`), violando as constraints NOT NULL de `question`, `response_type`, etc.

2. Adicionar o método `reorderSections` imediatamente antes do fechamento `}` da classe (após `reorderItems`):
   ```dart
   /// Reordena seções atualizando [order_index] via batch upsert em 1 query.
   /// Recebe a lista de IDs na nova ordem desejada.
   Future<void> reorderSections(List<String> ids) async {
     if (ids.isEmpty) return;
     final payload = [
       for (int i = 0; i < ids.length; i++)
         {'id': ids[i], 'order_index': i},
     ];
     await _client.from('template_sections').upsert(payload, defaultToNull: false);
   }
   ```
   Mesmo padrão de `reorderItems`, mas aponta para `template_sections`.
  </action>
  <verify>
    <automated>cd "C:/Users/eder3/Documents/Projetos/Projeto Audit/primeaudit" && dart analyze lib/services/audit_template_service.dart --fatal-infos 2>&1 | tail -5</automated>
  </verify>
  <done>
    - `reorderItems` contém `defaultToNull: false`
    - Método `reorderSections` existe na classe, aponta para `template_sections`, e usa `defaultToNull: false`
    - `dart analyze` sem erros no arquivo
  </done>
</task>

<task type="auto">
  <name>Task 2: Adicionar mounted guards, _persistSectionsOrder e ReorderableListView de seções na screen</name>
  <files>primeaudit/lib/screens/templates/template_builder_screen.dart</files>
  <action>
Quatro alterações neste arquivo:

**2a. Guard mounted em _persistSectionOrder (linha ~369):**
Substituir `_load();` por `if (mounted) _load();` dentro do catch de `_persistSectionOrder`.

**2b. Guard mounted em _persistUnsectionedOrder (linha ~380):**
Substituir `_load();` por `if (mounted) _load();` dentro do catch de `_persistUnsectionedOrder`.

**2c. Adicionar método _persistSectionsOrder após _persistUnsectionedOrder:**
```dart
// TMPL-02: persiste a nova ordem das seções após drag & drop.
Future<void> _persistSectionsOrder() async {
  try {
    await _service.reorderSections(_sections.map((s) => s.id).toList());
  } catch (_) {
    _showError('Erro ao salvar nova ordem das seções. A ordem foi restaurada.');
    if (mounted) _load();
  }
}
```

**2d. Alterar assinatura e corpo de _buildSection para receber sectionIndex (linha ~499):**
Mudar a assinatura de:
```dart
Widget _buildSection(TemplateSection section) {
```
para:
```dart
Widget _buildSection(TemplateSection section, int sectionIndex) {
```
No `Row` do cabeçalho (dentro do `Container` do header), adicionar o drag handle como PRIMEIRO filho do Row, antes do `Icon(Icons.folder_outlined)`:
```dart
ReorderableDragStartListener(
  index: sectionIndex,
  child: const Padding(
    padding: EdgeInsets.only(left: 4, right: 4),
    child: Icon(Icons.drag_handle_rounded, size: 18, color: AppColors.primary),
  ),
),
```
O Row existente já tem `children: [Icon(folder), SizedBox, Expanded(Text), Text(N itens), SizedBox, PopupMenuButton]`. O handle entra antes do `Icon(folder)`.

**2e. Substituir o flat map de seções por ReorderableListView (linha ~471):**
Substituir:
```dart
..._sections.map((s) => _buildSection(s)),
```
por:
```dart
if (_sections.isNotEmpty)
  ReorderableListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: false,
    onReorder: (int oldIndex, int newIndex) {
      if (oldIndex < newIndex) newIndex -= 1;
      setState(() {
        final section = _sections.removeAt(oldIndex);
        _sections.insert(newIndex, section);
      });
      _persistSectionsOrder();
    },
    children: [
      for (int i = 0; i < _sections.length; i++)
        KeyedSubtree(
          key: ValueKey(_sections[i].id),
          child: _buildSection(_sections[i], i),
        ),
    ],
  ),
```
`buildDefaultDragHandles: false` porque os handles explícitos estão no header via `ReorderableDragStartListener`. O `shrinkWrap: true` + `NeverScrollableScrollPhysics` preserva o comportamento existente dentro do `CustomScrollView`/`ListView` pai.
  </action>
  <verify>
    <automated>cd "C:/Users/eder3/Documents/Projetos/Projeto Audit/primeaudit" && dart analyze lib/screens/templates/template_builder_screen.dart --fatal-infos 2>&1 | tail -10</automated>
  </verify>
  <done>
    - `_persistSectionOrder` catch contém `if (mounted) _load()`
    - `_persistUnsectionedOrder` catch contém `if (mounted) _load()`
    - Método `_persistSectionsOrder` existe com guard mounted
    - `_buildSection` aceita `(TemplateSection section, int sectionIndex)`
    - Header Row tem `ReorderableDragStartListener` como primeiro filho
    - Seções são renderizadas dentro de `ReorderableListView` com `buildDefaultDragHandles: false`
    - `dart analyze` sem erros no arquivo
  </done>
</task>

</tasks>

<verification>
Após ambas as tasks:

```bash
cd "C:/Users/eder3/Documents/Projetos/Projeto Audit/primeaudit" && dart analyze lib/ 2>&1 | grep -E "error|warning" | head -20
```

Deve retornar zero erros. Warnings de lint existentes (se houver) não são regressão desta task.

Verificação manual (checkpoint implícito — não bloqueia execução):
1. Abrir um template no TemplateBuilderScreen
2. Arrastar um item dentro de uma seção — nenhum erro deve aparecer, ordem deve persistir após reload
3. Arrastar uma seção — handle aparece no cabeçalho, seção muda de posição, ordem persiste após reload
</verification>

<success_criteria>
- `dart analyze lib/` sem novos erros introduzidos por esta task
- `reorderItems` e `reorderSections` usam `defaultToNull: false`
- Drag de seções funciona no TemplateBuilderScreen (ReorderableListView com handles explícitos)
- Nenhum `setState after dispose` ao falhar save de ordem (mounted guards presentes)
</success_criteria>

<output>
Após conclusão, criar `.planning/quick/260423-qzs-corrigir-bug-de-ordena-o-e-adicionar-reo/260423-qzs-SUMMARY.md` com:
- Arquivos modificados
- Mudanças aplicadas (lista curta)
- Resultado do `dart analyze`
</output>
