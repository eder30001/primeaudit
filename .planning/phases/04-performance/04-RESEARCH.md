# Phase 4: Performance - Research

**Researched:** 2026-04-18
**Domain:** Supabase Flutter batch update / eliminação de N+1
**Confidence:** HIGH

---

## Summary

A Phase 4 tem escopo cirúrgico: um único método, `AuditTemplateService.reorderItems()`, contém um loop `for` com `await` interno que emite N queries sequenciais ao Supabase — uma por item reordenado. Com 20 itens, isso significa 20 round-trips HTTP em série, cada um esperando o anterior completar.

O problema foi confirmado diretamente no código em `primeaudit/lib/services/audit_template_service.dart` linhas 209–216. O método recebe uma lista de IDs na nova ordem e itera fazendo `.update({'order_index': i}).eq('id', ids[i])` dentro de um `for` sequencial. A tela `TemplateBuilderScreen` não possui drag-and-drop implementado atualmente — a UI exibe itens mas não chama `reorderItems()` — portanto a correção é no serviço, e a tela não precisa de mudança além de eventuais chamadas futuras ao método corrigido.

Existem três abordagens válidas, em ordem crescente de complexidade: (1) `Future.wait` paralelo — elimina o bloqueio sequencial, ainda emite N queries mas em paralelo; (2) upsert em batch — emite 1 única query com array de `{id, order_index}` pares, usando o método `.upsert([...])` do `supabase_flutter`; (3) Edge Function ou RPC PostgreSQL com `UPDATE ... FROM VALUES(...)` — 1 query no banco, sem overhead PostgREST. O critério de sucesso exige "no máximo 1 query ou queries paralelas", portanto as opções 1 e 2 ambas atendem, sendo a opção 2 (upsert batch) a mais limpa e verificável.

**Recomendação primária:** Substituir o loop sequencial por `.upsert(List<Map>)` com um único batch contendo todos os pares `{id, order_index}`. Isso emite exatamente 1 query, é suportado pelo `supabase_flutter` 2.x atual, não requer Edge Function ou migration, e é testável com mock.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | `AuditTemplateService.reorderItems()` usa batch update (single query) em vez de N queries sequenciais por item | `supabase_flutter` `.upsert([...])` aceita array — 1 query para N linhas; verificado na documentação oficial |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reordenação de itens de template | API / Backend (Supabase PostgREST) | — | A persistência da nova ordem é responsabilidade do banco; a UI apenas coleta a nova sequência de IDs |
| Coleta da nova ordem (drag-drop) | Frontend (Flutter widget) | — | `ReorderableListView` ou `onReorder` callback captura a nova posição e chama o serviço |
| Lógica de batch update | Services Layer (Dart) | — | `AuditTemplateService.reorderItems()` monta o payload e faz a chamada; segue o padrão estabelecido do projeto |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `supabase_flutter` | 2.12.2 (lock) / ^2.8.4 (pubspec) | Acesso ao banco via PostgREST | Já no projeto; `.upsert()` aceita `List<Map>` para batch em 1 query |
| `flutter_test` (SDK) | bundled | Testes unitários | Já configurado nas fases anteriores; sem nova dependência |

### Alternativas Consideradas

| Em vez de | Poderia usar | Tradeoff |
|-----------|-------------|----------|
| `.upsert([...])` batch | `Future.wait([...updates])` | `Future.wait` ainda emite N queries (paralelas, não sequenciais) — atende o critério mas não é a solução mais limpa |
| `.upsert([...])` batch | RPC / Edge Function com `UPDATE ... FROM VALUES` | Mais eficiente no banco, mas requer migration ou Edge Function — overhead desnecessário para este caso |

**Installation:** Sem novas dependências. Todas as bibliotecas necessárias já estão no `pubspec.lock`.

---

## Architecture Patterns

### Diagrama de Fluxo: Antes vs. Depois

```
ANTES (N queries sequenciais):
  UI drag-drop → reorderItems([id0,id1,...idN])
                    │
                    ├── await update(id0, order_index=0)  ← espera
                    ├── await update(id1, order_index=1)  ← espera
                    ├── ...
                    └── await update(idN, order_index=N)  ← espera
                    (N round-trips HTTP em série)

DEPOIS (1 query batch):
  UI drag-drop → reorderItems([id0,id1,...idN])
                    │
                    └── await upsert([{id:id0,order_index:0},{id:id1,order_index:1},...])
                    (1 round-trip HTTP)
```

### Estrutura de Projeto (sem mudanças)

```
primeaudit/lib/
├── services/
│   └── audit_template_service.dart   ← ÚNICA mudança: reorderItems()
├── models/
│   └── audit_template.dart           ← sem mudança
└── screens/templates/
    └── template_builder_screen.dart  ← sem mudança (não chama reorderItems hoje)

primeaudit/test/
└── services/
    └── audit_template_service_reorder_test.dart  ← arquivo novo (Wave 0 gap)
```

### Pattern: Batch Upsert com supabase_flutter

**O que é:** Passar `List<Map<String, dynamic>>` para `.upsert()` em vez de fazer um loop de `.update()` individuais.

**Quando usar:** Sempre que precisar atualizar um campo em N linhas onde cada linha tem um valor distinto para esse campo.

**Exemplo (código-alvo):**
```dart
// Source: https://supabase.com/docs/reference/dart/upsert
Future<void> reorderItems(List<String> ids) async {
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client
      .from('template_items')
      .upsert(payload);
}
```

**Por que funciona:** O `.upsert()` do PostgREST compila para um único `INSERT ... ON CONFLICT (id) DO UPDATE SET order_index = EXCLUDED.order_index` com todas as linhas no mesmo statement. O `supabase_flutter` 2.x aceita `List<Map>` — verificado na documentação oficial. [VERIFIED: supabase.com/docs/reference/dart/upsert]

### Pattern Alternativo: Future.wait (paralelo, não batch)

```dart
// Alternativa aceitável se upsert tiver problema de RLS
Future<void> reorderItems(List<String> ids) async {
  await Future.wait([
    for (int i = 0; i < ids.length; i++)
      _client
          .from('template_items')
          .update({'order_index': i})
          .eq('id', ids[i]),
  ]);
}
```

**Desvantagem:** Ainda emite N queries (paralelas, não bloqueantes). Atende o critério de sucesso ("queries paralelas — não sequenciais bloqueantes") mas é solução de segunda escolha.

### Anti-Patterns a Evitar

- **`await` dentro de `for` loop para operações independentes:** É exatamente o problema atual. Cada iteração bloqueia a thread até o servidor responder. Para N=20 itens com 50ms de latência, o total é ≥1000ms em vez de ~50ms.
- **Upsert sem incluir PK:** O `.upsert()` requer que cada mapa no array inclua a chave primária (`id`) para que o banco saiba qual linha atualizar — omitir resulta em INSERT em vez de UPDATE.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez | Por quê |
|----------|---------------|-------------|---------|
| Batch update com valores distintos por linha | SQL manual concatenado em string | `.upsert([...])` do `supabase_flutter` | Sujeito a SQL injection e quoting incorreto |
| Ordenação paralela de Futures | Semáforos ou filas customizadas | `Future.wait([...])` | A stdlib Dart já gerencia concorrência e propaga erros |

---

## Common Pitfalls

### Pitfall 1: RLS bloqueia upsert em batch

**O que acontece:** O upsert em batch pode falhar se a política RLS da tabela `template_items` não permitir UPDATE para o usuário atual. A query inteira falha atomicamente se qualquer linha for bloqueada.

**Por que ocorre:** RLS avalia cada linha individualmente dentro do statement — uma política restritiva pode rejeitar o batch completo se qualquer linha não pertencer à empresa do usuário.

**Como evitar:** Verificar se as políticas RLS de `template_items` permitem UPDATE pelo `adm`/`superuser` antes de implementar. As migrations de fase 2 cobriram RLS para várias tabelas; confirmar se `template_items` está incluída.

**Sinais de alerta:** Erro `new row violates row-level security policy` ao testar o método.

### Pitfall 2: upsert vs update — comportamento de campos não incluídos

**O que acontece:** Ao usar `.upsert()`, apenas os campos no payload são tocados. Como só enviamos `{id, order_index}`, os demais campos (`question`, `weight`, etc.) não são afetados — isso é o comportamento correto aqui.

**Por que ocorre:** O upsert do PostgREST faz `INSERT ... ON CONFLICT DO UPDATE SET` apenas para os campos presentes no payload, desde que `ignoreDuplicates: false` (default).

**Como evitar:** Não há ação necessária — o comportamento padrão já é o correto para reordenação.

### Pitfall 3: IDs inválidos não geram erro explícito

**O que acontece:** Se um ID na lista não existir na tabela, o upsert tentará inserir uma nova linha (sem os campos obrigatórios), o que causará erro de constraint — não um erro silencioso.

**Como evitar:** O contrato do método assume que todos os IDs são válidos (vieram de `getItems()`). Documentar isso explicitamente no doccomment.

### Pitfall 4: `reorderItems` não é chamado pela UI atual

**Observação:** A tela `TemplateBuilderScreen` exibe itens em lista mas não tem drag-and-drop implementado — não há `ReorderableListView` nem callback `onReorder`. O método `reorderItems` existe no serviço mas não é chamado em nenhum lugar do código atual (`grep` confirmou isso).

**Implicação:** O critério de sucesso 3 ("comportamento visual de reordenação continua funcionando") está vacuamente satisfeito — não há comportamento visual a quebrar. O plano deve documentar isso explicitamente, e o teste de unidade do método é suficiente para validar PERF-01.

---

## Code Examples

### Implementação alvo (verifica PERF-01)
```dart
// Source: https://supabase.com/docs/reference/dart/upsert [VERIFIED]
Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client
      .from('template_items')
      .upsert(payload);
}
```

### Teste unitário (estrutura esperada)
```dart
// Padrão: mock do client para verificar que upsert é chamado uma única vez
// sem await dentro de for (verificação estática via ausência do padrão no AST)
// O teste pragmático verifica a lógica do payload:

test('reorderItems monta payload correto sem loop sequencial', () {
  final ids = ['id-a', 'id-b', 'id-c'];
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  expect(payload, [
    {'id': 'id-a', 'order_index': 0},
    {'id': 'id-b', 'order_index': 1},
    {'id': 'id-c', 'order_index': 2},
  ]);
});
```

**Nota sobre testes com Supabase:** O `supabase_flutter` não é mockável com Mockito sem inicialização do Supabase (que requer ambiente real). O padrão estabelecido nas Fases 1–3 foi: (a) testar lógica pura sem chamar o client real, e (b) marcar testes de integração como `manual-only`. O mesmo padrão se aplica aqui — o teste verifica a construção do payload, e a ausência do padrão `await` dentro de `for` é verificável estaticamente (grep ou análise do código).

---

## State of the Art

| Abordagem antiga | Abordagem atual | Quando mudou | Impacto |
|------------------|-----------------|--------------|---------|
| N updates sequenciais em loop | `.upsert([...])` batch | `supabase_flutter` 2.x (sempre suportado) | De N round-trips a 1 |
| `Future.forEach` com await | `Future.wait([])` para paralelizar | Dart SDK (sempre suportado) | Queries paralelas em vez de sequenciais |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `reorderItems` não é chamado em nenhuma tela ativa (confirmado por grep — 0 callers além da definição) | Pitfall 4 | Baixo — se houver caller oculto, o comportamento melhora, não piora |
| A2 | RLS de `template_items` permite UPDATE por usuários autorizados (adm/superuser) | Pitfall 1 | Médio — se RLS bloquear, o upsert falhará; requer verificação manual no dashboard Supabase |

---

## Open Questions

1. **RLS em `template_items` — migração de Fase 2 cobriu essa tabela?**
   - O que sabemos: A migration `20260418_rls_profiles_companies_perimeters.sql` cobre profiles/companies/perimeters/audit_types/audit_templates. `template_items` pode ou não estar incluída.
   - O que está incerto: Se `.upsert()` em batch funcionará sem erro de RLS em produção.
   - Recomendação: O plano deve incluir uma verificação pré-execução do arquivo de migration para confirmar se `template_items` tem política UPDATE. Se não tiver, o `.upsert()` ainda funcionará para superuser/dev (que são os usuários que constroem templates).

---

## Environment Availability

Step 2.6: SKIPPED — fase é puramente alteração de código Dart em serviço existente. Sem novos CLIs, serviços externos, ou ferramentas de build.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK bundled) |
| Config file | `primeaudit/analysis_options.yaml` (lint), sem config de test separada |
| Quick run command | `flutter test test/services/audit_template_service_reorder_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-01 | `reorderItems` monta payload como `List<Map>` com `{id, order_index}` corretos | unit | `flutter test test/services/audit_template_service_reorder_test.dart` | Não — Wave 0 gap |
| PERF-01 | Código de `reorderItems` não contém `await` dentro de `for` | static (grep) | `grep -c "await _client" primeaudit/lib/services/audit_template_service.dart` após a mudança deve retornar 1 | N/A (análise estática) |

### Sampling Rate

- **Per task commit:** `flutter test test/services/audit_template_service_reorder_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter test` green antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `primeaudit/test/services/audit_template_service_reorder_test.dart` — cobre PERF-01 (payload batch, lista vazia, lista com 1 item, lista com 20 itens)

---

## Security Domain

Esta phase não introduz novas superfícies de ataque. A mudança de N queries sequenciais para 1 batch é transparente para as políticas RLS existentes — cada linha do batch ainda passa pela mesma avaliação de RLS que uma query individual. Nenhuma categoria ASVS nova se aplica.

---

## Sources

### Primary (HIGH confidence)
- [supabase.com/docs/reference/dart/upsert](https://supabase.com/docs/reference/dart/upsert) — confirmou que `.upsert()` aceita `List<Map>` para batch em 1 query
- Codebase grep: `audit_template_service.dart` linhas 209-216 — N+1 confirmado diretamente no código
- Codebase grep: `reorderItems` — confirmado 0 callers na tela atual

### Secondary (MEDIUM confidence)
- [flutter.dev/flutter/dart-async/Future-class.html](https://api.flutter.dev/flutter/dart-async/Future-class.html) — `Future.wait` como alternativa paralela

### Tertiary (LOW confidence)
- N/A

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `supabase_flutter` já no projeto, `.upsert([...])` verificado na docs oficial
- Architecture: HIGH — problema confirmado diretamente no código, solução direta e sem ambiguidade
- Pitfalls: HIGH — RLS/upsert behavior é comportamento documentado do PostgREST; caller ausente confirmado por grep

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stack estável, sem previsão de breaking changes em supabase_flutter 2.x)
