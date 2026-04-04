You are working on the PrimeAudit Flutter project. Your task is to create default audit templates and persist them in the Supabase database already used by the app.

Read these files first:
- `.claude/Audit.MD`
- `primeaudit/lib/services/audit_template_service.dart`
- `primeaudit/lib/models/audit_template.dart`
- `primeaudit/lib/models/audit_type.dart`
- `primeaudit/lib/screens/templates/template_builder_screen.dart`

Goal:
- Create default templates for audit types that already exist in `audit_types`.
- Do not create new audit types.
- Persist templates directly in the Supabase database used by the app.
- Make the templates immediately usable by the current UI.

Mandatory rules:
1. Use existing rows in `audit_types` as the source of truth.
2. Every template must be linked to an existing `type_id`.
3. If the audit type is global (`company_id` null), the template must also be global.
4. If the audit type belongs to a company, the template must inherit the same `company_id`.
5. Insert data into:
   - `audit_templates`
   - `template_sections`
   - `template_items`
6. Do not create duplicates:
   - Check whether a template with the same `name` and `type_id` already exists.
   - If it exists, do not duplicate it.
   - If it exists but is empty, you may populate its sections and items.
7. All user-facing content must be in Brazilian Portuguese.
8. Templates must be realistic for industrial/corporate auditing.
9. Use only supported response types:
   - `ok_nok`
   - `yes_no`
   - `scale_1_5`
   - `text`
   - `percentage`
   - `selection`
10. When `response_type = 'selection'`, provide valid `options`.
11. Set `required` and `weight` sensibly. Use weights from 1 to 5.
12. Use sequential `order_index` values for sections and items.
13. Do not trust `primeaudit/supabase/schema.sql` over the actual app code if they conflict. The current models/services are the main source of truth.
14. The final result must be executed and persisted, not only proposed.

What to create:
- For each existing audit type, create at least 1 default template.
- If appropriate, create more than 1 template per type, with clear distinct names.
- Each template must include:
  - name
  - description
  - 3 to 6 sections
  - 12 to 30 total items
- Items must be specific, auditable, and practically useful.

Expected content quality:
- Realistic templates for factory operations, quality, safety, process, compliance, logistics, 5S, HR, suppliers, and other types found in the database.
- Objective questions with professional wording.
- Short useful `guidance` text when needed.

Implementation strategy:
- Inspect existing audit types in the database.
- Build an idempotent seeding routine.
- You may choose the best technical approach:
  - executable Dart script
  - SQL script
  - temporary routine using the Supabase client
- Prefer a repeatable and maintainable approach.
- If you create a script, save it in an appropriate place in the project.
- Execute the routine to persist the data.

Expected delivery:
1. Implement the seed/population routine.
2. Execute it.
3. Confirm how many templates, sections, and items were created.
4. Provide a summary by audit type:
   - audit type name
   - created templates
   - section count
   - item count
5. List created/changed files.
6. If any audit type was skipped, explain exactly why.

Important:
- Do not stop at analysis.
- Do not return only a plan.
- Complete the implementation and write the data to the database.
- If you find inconsistencies between the code and the database, adapt to what the app actually uses.
