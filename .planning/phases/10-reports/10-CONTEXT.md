# Phase 10: Calendar Dashboard - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

> ⚠ **Scope change:** O escopo original de Relatórios (REP-01/02/03/04) foi removido pelo usuário.
> Esta fase entrega o **Calendário de Auditorias no Dashboard** em substituição.
> A opção de Relatórios deve ser removida do menu de navegação.

<domain>
## Phase Boundary

Adicionar um calendário mensal interativo ao dashboard (abaixo dos KPI cards existentes), mostrando auditorias agendadas por dia com indicadores de status. Tocar em um dia navega para a tela de auditorias filtrando apenas as auditorias daquele dia.

Não cria nova tela — o calendário é incorporado ao dashboard existente no `HomeScreen`.

**Fora do escopo desta fase:**
- Relatórios com filtros (REP-01/02/03/04) — removidos
- Edição de auditorias a partir do calendário
- Criação de auditorias a partir do calendário

</domain>

<decisions>
## Implementation Decisions

### Posição e Layout

- **D-01:** Calendário fica **abaixo dos 4 KPI cards existentes**, substituindo o espaço vazio/placeholder de atividade recente. Os cards não mudam.
- **D-02:** Navegação de mês via botões de seta (anterior / próximo). Mês atual exibido por padrão.

### Campo de Data

- **D-03:** A data usada para posicionar a auditoria no calendário é:
  - `deadline` se definido
  - `created_at` como fallback quando `deadline` é nulo
  - Auditorias com ambos nulos não aparecem (não esperado em produção)

### Indicadores por Dia

- **D-04:** 3 indicadores visuais por dia (ícone + número ou badge colorido):
  - **Novas** = `rascunho` + `em_andamento` (auditorias ativas sem atraso)
  - **Atrasadas** = `atrasada` (status já existente no enum `AuditStatus`)
  - **Concluídas** = `concluida`
  - `cancelada` ignorado — não aparece no calendário

### Navegação ao Tocar no Dia

- **D-05:** Tocar em um dia com auditorias navega para `AuditsScreen`, passando o dia selecionado como filtro. A `AuditsScreen` deve exibir apenas as auditorias daquele dia (baseado na mesma lógica de data: `deadline` ?? `created_at`).
- **D-06:** Dias sem auditorias são clicáveis mas não navegam (ou navegam para lista vazia — Claude decide o comportamento exato).

### Role Scoping

- **D-07:** O calendário segue o mesmo scoping do dashboard já estabelecido:
  - `auditor` → apenas suas próprias auditorias
  - `adm`/`admin` → todas da empresa ativa
  - `superuser`/`dev` → todas da empresa ativa via `CompanyContextService`

### Remoção dos Relatórios

- **D-08:** O item "Relatórios" deve ser removido do drawer/menu de navegação. Nenhuma nova tela de relatórios é criada nesta fase.

### Claude's Discretion

- Design visual dos indicadores: badges coloridos sobrepostos ao número do dia, dots abaixo do número, ou mini chips — Claude escolhe o que for mais legível no tamanho de célula de calendário.
- Implementação do calendário: widget customizado ou pacote Flutter (ex: `table_calendar`). Claude avalia se adicionar um pacote é justificado vs implementar o grid manualmente com `GridView`.
- Comportamento ao tocar em dia sem auditorias: Claude decide se navega para lista vazia ou ignora o toque.

### Hotfixes (ANTES do Phase 10)

Dois itens devem ser resolvidos como hotfix antes de executar esta fase:

- **HF-01:** Bug — seleção de responsável em ação corretiva: apenas o usuário logado aparece no dropdown; `UserService.getByCompany()` não está populando a lista com outros membros da empresa. Arquivo afetado: `primeaudit/lib/screens/create_corrective_action_screen.dart`.
- **HF-02:** Feature — excluir tipo de auditoria: adicionar opção de exclusão em `primeaudit/lib/screens/templates/audit_types_screen.dart` (swipe ou menu de contexto em `_buildTypeCard`). Verificar se há auditorias vinculadas antes de excluir (integridade referencial).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tela principal (modificar, não criar nova)
- `primeaudit/lib/screens/home_screen.dart` — Dashboard com `_buildDashboard()`, KPI cards, `_loadDashboard()`, lógica de role. O calendário é inserido aqui.

### Services existentes (reutilizar)
- `primeaudit/lib/services/audit_service.dart` — `getAudits({String? companyId})` — fonte de dados para o calendário. Considerar adicionar filtro por mês para performance.
- `primeaudit/lib/services/company_context_service.dart` — `CompanyContextService.instance.activeCompanyId` — scope de empresa.
- `primeaudit/lib/services/dashboard_service.dart` — Padrão de serviço de agregação para o dashboard. Pode ser estendido com método de dados para o calendário.

### Models
- `primeaudit/lib/models/audit.dart` — `AuditStatus` enum (rascunho, em_andamento, atrasada, concluida, cancelada), `Audit.deadline`, `Audit.createdAt`, `Audit.conformityPercent`.

### Navegação destino
- `primeaudit/lib/screens/audits_screen.dart` — Destino ao tocar em dia. Verificar se aceita parâmetro de filtro de data ou se precisa ser adicionado.

### Contexto Phase 7 (padrões do dashboard)
- `.planning/phases/07-dashboard/07-CONTEXT.md` — Decisões D-01 a D-07 do dashboard (KPI cards, role scoping, pull-to-refresh, fl_chart). O calendário segue os mesmos padrões.

### Hotfixes
- `primeaudit/lib/screens/create_corrective_action_screen.dart` — HF-01: bug na lista de responsáveis
- `primeaudit/lib/screens/templates/audit_types_screen.dart` — HF-02: adicionar exclusão de tipo

### Requisitos (para referência — escopo original alterado)
- `.planning/REQUIREMENTS.md` — REP-01/02/03/04 marcados como removidos desta fase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_summaryCard({icon, label, value, color})` em `home_screen.dart` — widget de KPI que permanece intacto acima do calendário.
- `CompanyContextService.instance.activeCompanyId` — fonte de verdade para filtro de empresa.
- `AuditStatus` enum — todos os status que determinam o indicador do dia (rascunho, em_andamento, atrasada, concluida).
- `AppColors`, `AppTheme.of(context)` — tokens de cor/tema para manter consistência visual do calendário.
- `_loadDashboard()` em `home_screen.dart` — método de refresh já existente; o carregamento dos dados do calendário deve ser integrado aqui (ou chamado junto).

### Established Patterns
- `setState()` com `_isLoading` / `_error` — padrão de todas as telas; o calendário segue o mesmo.
- Services instanciados localmente: `final _dashboardService = DashboardService()`.
- `RefreshIndicator` wrapping `SingleChildScrollView` — já presente; calendário fica dentro deste scroll.
- Navegação via `Navigator.push(context, MaterialPageRoute(...))` — padrão para navegar para `AuditsScreen`.

### Integration Points
- `_buildDashboard()` em `home_screen.dart` — o calendário é adicionado como novo `Column` child, abaixo dos 2 `Row` de KPI cards.
- `AuditsScreen` precisará aceitar um parâmetro opcional de data para filtrar auditorias do dia selecionado. Verificar o construtor atual antes de planejar.
- `fl_chart` já instalado (Phase 7) — NÃO adicionar novamente ao pubspec.

</code_context>

<specifics>
## Specific Ideas

- O calendário mostra **sempre o mês atual** ao abrir; navegação livre entre meses via setas.
- Indicadores por dia devem ser visualmente distintos: cor diferente para cada status (Novas = azul/accent, Atrasadas = vermelho/error, Concluídas = verde).
- A lógica de data `deadline ?? created_at` deve ser consistente entre o calendário e o filtro da `AuditsScreen` ao tocar no dia.

</specifics>

<deferred>
## Deferred Ideas

- **Relatórios com filtros** (REP-01/02/03/04) — removidos do roadmap atual. Se necessário no futuro, novo phase dedicado.
- **Criar auditoria a partir do calendário** — tocar em dia vazio e criar nova auditoria com deadline pré-preenchido. Fora do escopo desta fase.
- **Indicador de conformidade no calendário** — cor do dia baseada na conformidade média. Fora do escopo.
- **Calendário em tempo real via Supabase Realtime** — atualização automática sem pull-to-refresh. Fora do escopo.

</deferred>

---

*Phase: 10-reports (Calendar Dashboard)*
*Context gathered: 2026-04-29*
