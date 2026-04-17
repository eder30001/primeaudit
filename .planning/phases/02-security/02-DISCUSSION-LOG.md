# Phase 2: Security - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 02-security
**Areas discussed:** CNPJ checksum, active=false RLS, Escopo do audit RLS, Documentação RLS

---

## CNPJ checksum (SEC-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Só register_screen | Escopo mínimo, só ponto de entrada público | |
| Register + company_form | Consistente, cobre os dois pontos de digitação | ✓ |
| Register + company_form + server-side | Máxima proteção, requer Supabase function/trigger | |

**User's choice:** Register + company_form (admin)
**Notes:** "no cadastro de usuario e no cadastro da empresa é onde devemos validar o CNPJ"

### Helper location

| Option | Description | Selected |
|--------|-------------|----------|
| lib/core/cnpj_validator.dart | Arquivo dedicado, reutilizável, testável | ✓ |
| Inline nos validators | Simples mas duplica lógica | |

**User's choice:** lib/core/cnpj_validator.dart

---

## active=false (SEC-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Modificar get_my_role() | Retornar NULL quando active=false — cobre todas as policies de uma vez | ✓ |
| Checagem em cada policy | AND active em cada USING — mais verboso, mais auditável | |

**User's choice:** Claude decidiu (usuário pediu para Claude tomar as melhores decisões)
**Notes:** Modificar get_my_role() é a opção mais robusta — uma mudança cobre tudo automaticamente.

---

## Escopo do audit RLS

| Option | Description | Selected |
|--------|-------------|----------|
| Só gaps críticos (profiles, companies) | Menor escopo | |
| Todas as tabelas | Fecha todos os gaps incluindo perimeters/templates/items sem nenhuma policy | ✓ |

**User's choice:** Claude decidiu (usuário pediu para Claude tomar as melhores decisões)
**Notes:** perimeters, audit_templates, audit_types, template_items não têm nenhuma policy — gap de segurança que deve ser fechado nesta fase.

---

## Documentação RLS (SEC-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Comentário em supabase_config.dart | Inline, menos visível | |
| SECURITY-AUDIT.md dedicado | Arquivo próprio, mais legível e auditável | ✓ |
| SQL comments na migration | Dentro do arquivo SQL | |

**User's choice:** Claude decidiu (usuário pediu para Claude tomar as melhores decisões)
**Notes:** Arquivo markdown dedicado é mais fácil de revisar e atualizar sem mexer no código.

---

## Claude's Discretion

- Abordagem interna do `cnpj_validator.dart` (função pura vs. classe estática)
- Ordem/consolidação das migrations novas
- Policies para templates globais (`company_id IS NULL`)

## Deferred Ideas

- Dashboard com dados reais nos cards — nova fase de feature
- Bottom navigation bar substituindo drawer — fase de UI separada
- Validação server-side de CNPJ — desnecessária dado cobertura Flutter
