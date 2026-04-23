# Phase 7: Dashboard - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Transformar o `_buildDashboard()` existente em `home_screen.dart` de placeholder para dashboard real: 4 KPI cards com dados reais do Supabase scoped por empresa, pull-to-refresh, e gráfico de conformidade média por template (fl_chart).

Não cria nova tela de navegação — o dashboard continua sendo o body do `HomeScreen`.

</domain>

<decisions>
## Implementation Decisions

### KPI Cards — Definições

- **D-01:** Card **"Total"** = todas as auditorias exceto canceladas: `rascunho + em_andamento + concluida + atrasada`. Canceladas são excluídas do total.
- **D-02:** Card **"Pendentes"** = apenas `em_andamento`. Rascunhos não contam como pendente — são drafts não iniciados.
- **D-03:** Card **"Atrasadas"** = auditorias com `status == atrasada` (já existente no enum `AuditStatus`).
- **D-04:** Card **"Ações abertas"** = count da tabela `corrective_actions` (Phase 8). Antes da migration existir, retornar `0` como fallback — card sempre visível com valor zero.

### KPIs — Role-Based

- **D-05:** **Auditor** vê apenas suas próprias auditorias (`auditor_id == currentUser.id`). Cards de Total, Pendentes e Atrasadas filtram por auditor logado.
- **D-06:** **Admin/Adm** vê todas as auditorias da empresa ativa (`company_id == activeCompanyId`), sem filtro de auditor — visão consolidada.
- **D-07:** **Superuser/Dev** segue o mesmo escopo de Admin/Adm (empresa ativa via `CompanyContextService`) + exibe um **4º card extra** com o total de empresas cadastradas. Claude tem discrição sobre o conteúdo exato do card extra — "total de empresas" é o placeholder atual e faz sentido como métrica de operação.

### Claude's Discretion

- **Estratégia de dados:** Claude decide entre fetch completo + count em Dart vs COUNT queries individuais no Supabase. Considerando que `AuditService.getAudits()` já existe e o volume de auditorias por empresa é baixo/médio, fetch único com contagem em Dart é aceitável. DashboardService novo somente se necessário para isolar lógica de agregação.
- **Gráfico (DASH-03):** Claude decide tipo (bar chart horizontal recomendado para comparar templates) e período ("recente" = últimos 90 dias ou sem filtro — usar dados disponíveis de `conformity_percent` nas auditorias concluídas). fl_chart já decidido como biblioteca.
- **Layout:** Claude decide posicionamento do gráfico no scroll (abaixo dos 4 cards, substituindo a seção "Atividade recente" placeholder).
- **Pull-to-refresh (DASH-02):** `RefreshIndicator` wrapping o `SingleChildScrollView` existente — atualiza todos os KPIs e o gráfico.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Código existente (leitura obrigatória antes de planejar)
- `primeaudit/lib/screens/home_screen.dart` — Dashboard atual com `_buildDashboard()`, `_summaryCard()`, e lógica de role. Modificar este arquivo, não criar novo.
- `primeaudit/lib/services/audit_service.dart` — `getAudits({String? companyId})` — método base para buscar auditorias por empresa.
- `primeaudit/lib/models/audit.dart` — `AuditStatus` enum e `Audit.isOverdue` getter.
- `primeaudit/lib/services/company_context_service.dart` — `CompanyContextService.instance.activeCompanyId` — scope de empresa.
- `primeaudit/lib/core/app_roles.dart` — `AppRole.canAccessAdmin()`, `AppRole.isSuperOrDev()` — checks de role usados no dashboard atual.

### Dependência Phase 8
- `corrective_actions` tabela ainda não existe — retornar 0 como fallback para o card de ações abertas. Quando Phase 8 for executada, a query pode ser ativada.

### Biblioteca gráfica
- `fl_chart` — adicionar ao `primeaudit/pubspec.yaml`. Será reutilizado na Phase 10 (REP-04) — **não adicionar duas vezes**.

### Requisitos
- `DASH-01`, `DASH-02`, `DASH-03` em `.planning/REQUIREMENTS.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_summaryCard({icon, label, value, color})` — widget privado em `home_screen.dart`. Já tem o layout correto (icon colorido + label + value). Só precisa receber valores reais ao invés de `'—'`.
- `CompanyContextService.instance.activeCompanyId` — fonte de verdade para o scope de empresa.
- `AuditStatus` enum com todos os status necessários (`emAndamento`, `atrasada`, etc.).
- `AppRole.canAccessAdmin(_role)` e `AppRole.isSuperOrDev(_role)` — já usados na tela para visibilidade condicional.

### Established Patterns
- `setState()` com boolean `_isLoading` e `_error` string — padrão de todas as telas.
- Services instanciados localmente: `final _auditService = AuditService()`.
- `_load()` chamado no `initState()`, retorna `setState()` no final/catch.
- Exceptions não tratadas dentro do service — `try/catch` fica na tela.

### Integration Points
- `_buildDashboard()` em `home_screen.dart` — ponto de entrada. Atualmente retorna widgets estáticos; passará a usar dados de `_dashboardData` ou campos de estado.
- `_loadProfile()` já existe em `initState()` — o `_load()` do dashboard deve rodar após o profile (role disponível para o scope correto).

</code_context>

<specifics>
## Specific Ideas

- O card "Ações abertas" deve sempre renderizar (nunca ocultar) — mesmo que o valor seja 0 antes da Phase 8 existir. Isso garante consistência visual e evita reflow de layout quando a tabela for criada.
- Role mapping para data scope: `auditor` → filtra por `auditor_id`; `adm`/`admin` → filtra por `company_id`; `superuser`/`dev` → filtra por `company_id` (empresa ativa via `CompanyContextService`) + exibe card extra.

</specifics>

<deferred>
## Deferred Ideas

- **Gráfico interativo com filtro de período** — usuário seleciona intervalo para o gráfico. Complexidade extra; manter simples nesta fase.
- **Atividade recente com lista de auditorias** — a seção "Atividade recente" placeholder pode virar lista das últimas N auditorias. Fora do escopo do DASH-01/02/03 — candidato para fase futura ou Phase 10.
- **KPIs em tempo real via Realtime** — usar Supabase Realtime para atualizar cards sem pull-to-refresh. Fora do escopo desta fase.

</deferred>

---

*Phase: 07-dashboard*
*Context gathered: 2026-04-23*
