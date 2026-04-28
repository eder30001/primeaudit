---
phase: 09-images
plan: 01
subsystem: database
tags: [supabase, storage, image_picker, flutter, android, rls, migration]

# Dependency graph
requires:
  - phase: 08-corrective-actions
    provides: "padrão idempotente de migrations SQL; funções RLS get_my_role()/get_my_company_id()"
provides:
  - "Tabela audit_item_images com 7 colunas, 4 FKs, 3 índices e 5 políticas RLS"
  - "Bucket Storage audit-images (privado) com 3 políticas de acesso por company_id"
  - "Dependência image_picker ^1.1.2 declarada e resolvida (1.2.2)"
  - "3 permissões Android para câmera e galeria em AndroidManifest.xml"
affects: [09-02, 09-03, ImageService, AuditExecutionScreen]

# Tech tracking
tech-stack:
  added:
    - "image_picker: ^1.1.2 (resolvido 1.2.2) — camera + gallery picker"
  patterns:
    - "Bucket Storage privado criado via migration SQL (INSERT INTO storage.buckets ON CONFLICT DO NOTHING)"
    - "Path de imagem: {companyId}/{auditId}/{itemId}/{uuid}.jpg — first segment = company_id"
    - "RLS Storage via storage.foldername(name)[1] = get_my_company_id()::text"

key-files:
  created:
    - "primeaudit/supabase/migrations/20260427_create_audit_item_images.sql"
  modified:
    - "primeaudit/pubspec.yaml"
    - "primeaudit/pubspec.lock"
    - "primeaudit/android/app/src/main/AndroidManifest.xml"

key-decisions:
  - "image_picker ^1.1.2 — versão mínima compatível com API Android moderna; resolvido como 1.2.2 via semver"
  - "Bucket audit-images declarado como public: false — acesso exclusivo via signed URLs (1h)"
  - "Storage RLS inclusa na migration — não necessita configuração manual no Dashboard"
  - "auditor INSERT restrito a created_by = auth.uid() — proteção T-09-01 (spoofing)"

patterns-established:
  - "Migration de Storage bucket: INSERT INTO storage.buckets ON CONFLICT DO NOTHING"
  - "Storage RLS usa storage.foldername(name)[1] para validar primeiro segmento do path"

requirements-completed: [IMG-01, IMG-02, IMG-03]

# Metrics
duration: 15min
completed: 2026-04-27
---

# Phase 09 Plan 01: Images Infrastructure Summary

**Tabela `audit_item_images` + bucket Storage privado `audit-images` + `image_picker 1.2.2` + permissões Android — fundação completa para upload de fotos por pergunta de auditoria**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-27T00:00:00Z
- **Completed:** 2026-04-27
- **Tasks:** 2/3 concluídas (Task 2 pendente — ação manual necessária; ver abaixo)
- **Files modified:** 4

## Accomplishments
- Migration SQL idempotente criada: tabela `audit_item_images` com 7 colunas, 4 FKs (audit ON DELETE CASCADE), 3 índices, RLS habilitado com 5 políticas
- Bucket Storage `audit-images` (privado) declarado na migration com 3 políticas RLS restritas a `get_my_company_id()`
- `image_picker: ^1.1.2` adicionado ao pubspec.yaml; resolvido como `1.2.2`; `flutter pub get` limpo
- 3 permissões Android declaradas no AndroidManifest.xml (CAMERA, READ_EXTERNAL_STORAGE maxSdk=32, READ_MEDIA_IMAGES)

## Task Commits

1. **Task 1: Migration SQL audit_item_images + bucket + RLS** - `dfae3e5` (feat)
2. **Task 2: supabase db push** - PENDENTE (ver User Setup Required)
3. **Task 3: image_picker + AndroidManifest permissions** - `375c5ef` (feat)

## Files Created/Modified
- `primeaudit/supabase/migrations/20260427_create_audit_item_images.sql` — DDL completo (127 linhas): tabela, colunas, FKs, índices, 5 RLS policies, bucket, 3 Storage policies
- `primeaudit/pubspec.yaml` — adicionado `image_picker: ^1.1.2`
- `primeaudit/pubspec.lock` — atualizado com 14 novos pacotes (image_picker + dependências de plataforma)
- `primeaudit/android/app/src/main/AndroidManifest.xml` — 3 permissões antes de `<application>`

## Decisions Made
- Seguido padrão idempotente exato das migrations anteriores (DROP CONSTRAINT IF EXISTS / ADD CONSTRAINT)
- RLS de Storage incluída na migration para evitar configuração manual no Dashboard
- `image_picker` versão `^1.1.2` permite 1.2.x — resolvido como 1.2.2 (mais recente compatível)

## Deviations from Plan

### Auto-fixed Issues

Nenhuma auto-correção necessária.

## Issues Encountered

**Task 2 — supabase CLI não disponível no ambiente de execução**

O comando `supabase db push` requer o Supabase CLI instalado, que não está presente no PATH da máquina de desenvolvimento. A migration SQL foi criada e commitada corretamente; apenas a aplicação ao banco remoto está pendente.

Esta situação está documentada na seção "User Setup Required" abaixo.

## User Setup Required

**A migration precisa ser aplicada manualmente ao banco Supabase remoto.**

### Opção A: Via Supabase CLI (recomendado)

```bash
# 1. Instalar Supabase CLI (se não instalado)
# Windows (Scoop): scoop install supabase
# Ou: https://supabase.com/docs/guides/cli/getting-started

# 2. Autenticar
supabase login

# 3. Aplicar migration
cd primeaudit
supabase db push
```

Verificar saída sem "ERROR" e com "Done" ou "Migrations applied".

### Opção B: Via Supabase Dashboard (SQL Editor)

1. Abrir Supabase Dashboard > SQL Editor
2. Copiar o conteúdo de `primeaudit/supabase/migrations/20260427_create_audit_item_images.sql`
3. Executar o script completo
4. Verificar em Table Editor que `audit_item_images` existe com as colunas
5. Verificar em Storage > Buckets que `audit-images` existe (privado)

### Verificação pós-aplicação

- Table Editor: tabela `audit_item_images` com 7 colunas
- Authentication > Policies: 5 políticas em `audit_item_images`
- Storage > Buckets: bucket `audit-images` (privado = sim)
- Storage > Policies: 3 políticas em `storage.objects` para bucket `audit-images`

## Next Phase Readiness

- **09-02 (ImageService):** Pode iniciar após a migration ser aplicada ao banco. O código Dart pode ser escrito antes (não depende do banco para compilar).
- **09-03 (UI _ImageStrip):** Pode iniciar após 09-02.
- **Bloqueio crítico:** A migration deve estar aplicada antes de qualquer teste real de upload no app.

---
*Phase: 09-images*
*Completed: 2026-04-27*
