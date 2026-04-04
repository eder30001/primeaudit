# PrimeAudit — Documentação Completa do Projeto

> **IMPORTANTE:** Leia este arquivo ANTES de iniciar qualquer trabalho no projeto.

---

## 1. Visão Geral

**PrimeAudit** é um aplicativo Flutter de gerenciamento de auditorias industriais/corporativas.
Backend: **Supabase** (PostgreSQL + Auth).
Plataforma alvo: Android/iOS (mobile-first), com suporte web e macOS.

**Objetivo do sistema:** Permitir que empresas criem e executem auditorias padronizadas por meio de templates configuráveis, com controle de acesso por papel (role).

---

## 2. Stack e Dependências

| Dependência | Versão | Uso |
|---|---|---|
| Flutter SDK | Dart ^3.11.4 | Framework principal |
| supabase_flutter | ^2.8.4 | Backend (DB + Auth) |
| shared_preferences | ^2.3.3 | Persistência local (settings, tema, empresa ativa) |
| cupertino_icons | ^1.0.8 | Ícones iOS |
| flutter_lints | ^6.0.0 | Qualidade de código |

**Sem** Provider, GetX, Riverpod ou GoRouter — estado gerenciado via `setState` + `ValueNotifier` + Singletons.

---

## 3. Estrutura de Pastas

```
primeaudit/
├── lib/
│   ├── main.dart                  # Entry point, Supabase init, AuthGate, tema global
│   ├── core/
│   │   ├── app_colors.dart        # Paleta de cores (primary: #1E3A5F, accent: #2196F3)
│   │   ├── app_roles.dart         # Papéis e helpers de permissão
│   │   ├── app_theme.dart         # Light/Dark themes (Material 3)
│   │   └── supabase_config.dart   # URL + anon key do Supabase
│   ├── models/
│   │   ├── app_user.dart          # Perfil do usuário
│   │   ├── company.dart           # Empresa/organização
│   │   ├── audit_type.dart        # Tipo de auditoria (categoria)
│   │   ├── audit_template.dart    # Template + TemplateSection + TemplateItem
│   │   └── perimeter.dart         # Perímetro/escopo hierárquico
│   ├── services/
│   │   ├── auth_service.dart      # Login, registro, logout, mudança de senha
│   │   ├── company_service.dart   # CRUD de empresas
│   │   ├── user_service.dart      # CRUD de usuários/perfis
│   │   ├── company_context_service.dart  # Singleton: empresa ativa no contexto
│   │   ├── audit_template_service.dart   # CRUD: tipos, templates, seções, itens
│   │   ├── perimeter_service.dart # CRUD de perímetros (árvore hierárquica)
│   │   └── settings_service.dart  # Configurações locais via SharedPreferences
│   └── screens/
│       ├── login_screen.dart      # Tela de login
│       ├── register_screen.dart   # Tela de registro
│       ├── home_screen.dart       # Dashboard + Drawer de navegação
│       ├── profile_screen.dart    # Perfil do usuário
│       ├── settings_screen.dart   # Configurações do app
│       ├── admin/
│       │   ├── admin_screen.dart  # Painel admin (TabBar: Empresas | Usuários)
│       │   ├── companies_tab.dart # Lista e CRUD de empresas
│       │   ├── company_form.dart  # Formulário de empresa (modal)
│       │   ├── users_tab.dart     # Lista e CRUD de usuários
│       │   └── perimeters_screen.dart # Gerenciamento de perímetros
│       └── templates/
│           ├── audit_types_screen.dart      # CRUD de tipos de auditoria
│           ├── audit_templates_screen.dart  # CRUD de templates por tipo
│           └── template_builder_screen.dart # Builder visual: seções + itens (drag-drop)
└── supabase/                      # Configuração local do Supabase (migrations, seed)
```

---

## 4. Backend — Supabase

**URL:** `https://chhodscgwzpixtrvbywm.supabase.co`
**Autenticação:** Email/senha via Supabase Auth
**Banco de dados:** PostgreSQL gerenciado pelo Supabase

### Schema do Banco (inferido dos models/services)

| Tabela | Colunas principais |
|---|---|
| `auth.users` | Gerenciado pelo Supabase Auth |
| `profiles` | id, full_name, email, role, company_id, active, created_at |
| `companies` | id, name, cnpj, email, phone, address, active, requires_perimeter, created_at |
| `audit_types` | id, name, icon (emoji), color (hex), company_id, active |
| `audit_templates` | id, type_id, company_id, name, description, active |
| `template_sections` | id, template_id, name, order_index |
| `template_items` | id, template_id, section_id, question, guidance, response_type, required, weight, order_index, options |
| `perimeters` | id, company_id, parent_id, name, description, active, created_at |

### Tipos de Resposta de Item de Template
`ok_nok` | `yes_no` | `scale_1_5` | `text` | `percentage` | `selection`

---

## 5. Papéis de Usuário (Roles)

| Role | Label | Permissões |
|---|---|---|
| `superuser` | Super Usuário | Acesso total a tudo |
| `dev` | Desenvolvedor | Acesso total + features de dev |
| `adm` | Administrador | Acesso admin da sua empresa |
| `auditor` | Auditor | Acesso às auditorias da empresa |
| `anonymous` | Anônimo | Acesso mínimo |

**Helpers em `app_roles.dart`:**
- `canAccessAdmin()` → superuser, dev, adm
- `canAccessDev()` → superuser, dev
- `isSuperOrDev()` → superuser, dev

---

## 6. Gerenciamento de Estado

- **Tema global:** `ValueNotifier<ThemeMode> appThemeMode` em `main.dart`
- **Empresa ativa:** `CompanyContextService` (Singleton) — persiste via SharedPreferences
  - superuser/dev podem trocar entre empresas
  - outros roles usam a empresa do perfil
- **Estado local de telas:** `StatefulWidget` + `setState()`
- **Serviços:** Instanciados diretamente nas State classes (sem DI container)

---

## 7. Navegação

Navegação imperativa sem named routes:
```
_AuthGate
├── LoginScreen
│   └── RegisterScreen
└── HomeScreen (Drawer)
    ├── ProfileScreen
    ├── SettingsScreen
    ├── AdminScreen (TabBar)
    │   ├── CompaniesTab → CompanyForm (modal)
    │   └── UsersTab
    ├── PerimetersScreen
    ├── AuditTypesScreen
    ├── AuditTemplatesScreen
    └── TemplateBuilderScreen
```

---

## 8. Configurações (SettingsService)

Persistidas via `SharedPreferences`:

| Categoria | Setting | Padrão |
|---|---|---|
| Aparência | Tema (light/dark/system) | system |
| Notificações | Auditorias atribuídas | true |
| Notificações | Prazos | true |
| Notificações | Relatórios | false |
| Auditoria | Duração padrão (dias) | 7 |
| Auditoria | Conformidade mínima (%) | 80 |
| Auditoria | Exigir justificativa | true |
| Auditoria | Permitir edição após envio | false |
| Sistema | Modo manutenção | false |

---

## 9. Classificação de Auditorias por IA

O sistema usa IA para classificar auditorias automaticamente em **Tipo** e **Template**.

### Formato de saída obrigatório:
```
Tipo: <nome do tipo>
Template: <nome do template>
```

### Tipos e Templates disponíveis:

**Qualidade:** Produto Final, Processo, Linha de Produção, Retrabalho, Setup, Poka-Yoke, Controle de Qualidade, First Piece
**Segurança (EHS):** Uso de EPI, Condições de Segurança, Auditoria Comportamental, Inspeção de Máquinas Seguras, LOTO, Trabalho em Altura, Espaço Confinado, Extintores, Rota de Fuga
**Processo:** Trabalho Padronizado, Instrução de Trabalho, Setup de Máquina, SMED, Fluxo de Processo, Balanceamento de Linha
**Meio Ambiente:** Gestão de Resíduos, Controle de Emissões, Armazenamento Químicos, Prevenção de Vazamentos, Consumo de Água/Energia, Sustentabilidade
**Compliance/Normas:** ISO 9001, IATF 16949, Procedimentos Internos, Documentação, Requisitos Legais
**LPA:** Nível 1 (Operador), Nível 2 (Líder), Nível 3 (Supervisor), Nível 4 (Gerência)
**Logística:** Armazenagem, Inventário, Expedição, Recebimento, FIFO
**5S/Organização:** 5S Completa, Limpeza, Organização, Padronização, Disciplina
**Recursos Humanos:** Treinamento, Competência, Integração (Onboarding), Registros
**Fornecedores:** Auditoria de Fornecedor, Avaliação, Processo do Fornecedor, Qualidade do Fornecedor

**Regras:** Um único Tipo + um único Template compatível. Se não houver correspondência → "Template não identificado".

---

## 10. Funcionalidades Implementadas

- [x] Autenticação (login/registro/logout/mudança de senha)
- [x] Controle de acesso baseado em papéis (RBAC)
- [x] Gerenciamento de empresas (CRUD)
- [x] Gerenciamento de usuários (CRUD + ativação/desativação)
- [x] Gerenciamento de tipos de auditoria (com ícone emoji e cor)
- [x] Gerenciamento de templates de auditoria
- [x] Builder visual de templates (seções + itens com drag-drop)
- [x] Perímetros hierárquicos (árvore parent-child)
- [x] Contexto de empresa ativo (troca de empresa para superuser/dev)
- [x] Tema light/dark com persistência
- [x] Configurações do sistema por role
- [x] Material 3 design

## 11. Funcionalidades a Implementar (Próximos Passos)

- [ ] Execução de auditorias (aplicar template em um perímetro)
- [ ] Histórico de auditorias realizadas
- [ ] Planos de ação (não conformidades)
- [ ] Dashboard com métricas e gráficos
- [ ] Exportação de relatórios (PDF)
- [ ] Notificações push
- [ ] Modo offline

---

## 12. Convenções do Código

- Dart 3 com null-safety
- Nomes de arquivos: `snake_case`
- Classes: `PascalCase`
- Métodos/variáveis: `camelCase`
- Strings de UI em português (BR)
- Supabase chamado diretamente nos services (sem camada de repositório adicional)
- Erros tratados com `try/catch` + `SnackBar` para feedback ao usuário
- Sem `async` em `initState` diretamente — usar `Future.microtask` ou chamar método separado

---

## 13. Desenvolvimento Local

```bash
cd primeaudit
flutter pub get
flutter run
```

Supabase URL e anon key estão em `lib/core/supabase_config.dart`.

---

*Última atualização: 2026-04-01*
